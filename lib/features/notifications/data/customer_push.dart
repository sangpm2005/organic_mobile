import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';
import 'push_gateway.dart';

/// Token binding follows the authenticated account, never an accountId from UI.
class CustomerPush extends ChangeNotifier {
  final OrganicApi api;
  final FlutterSecureStorage storage;
  final String? Function() owner;
  final PushGateway gateway;
  CustomerPush(this.api, this.storage, this.owner, {PushGateway? gateway})
    : gateway = gateway ?? FirebasePushGateway();
  StreamSubscription<String>? _tokens;
  StreamSubscription<PushEvent>? _messages;
  final _events = StreamController<PushEvent>.broadcast();
  Stream<PushEvent> get events => _events.stream;
  PushEvent? pendingOpen;
  bool enabled = false, busy = false, _disposed = false, _ready = false;
  String? error, _token, _boundOwner;
  Future<void> _registration = Future.value();
  Future<void> _revocation = Future.value();
  String _key(String id) => 'organicfood.push.v1.$id';
  bool _current(String id, int version) =>
      !_disposed &&
      owner() == id &&
      api.accessToken != null &&
      api.sessionVersion == version;

  Future<void> _initialize() async {
    if (_ready) return;
    await gateway.initialize();
    if (_disposed) return;
    _ready = true;
    _tokens = gateway.tokens.listen(
      (token) {
        if (enabled) {
          unawaited(
            _register(token).catchError((Object e) {
              error = '$e';
              _notify();
            }),
          );
        }
      },
      onError: (Object _) {
        error = 'Chưa cập nhật được đăng ký thông báo. Vui lòng thử bật lại.';
        _notify();
      },
    );
    _messages = gateway.events.listen(
      _receive,
      onError: (Object _) {
        error = 'Chưa nhận được thông báo đẩy. Hộp thư trong ứng dụng vẫn dùng được.';
        _notify();
      },
    );
  }

  void _receive(PushEvent event) {
    if (_disposed ||
        !enabled ||
        _boundOwner != owner() ||
        event.data['type'] != 'CUSTOMER_INBOX' ||
        event.data['accountId'] != owner()) {
      return;
    }
    if (event.opened) pendingOpen = event;
    _events.add(event);
  }

  Future<void> _register(String token) {
    final id = owner(), version = api.sessionVersion;
    if (id == null || token.isEmpty) return Future.value();
    final pending = _registration.catchError((Object _) {}).then((_) async {
      if (!_current(id, version)) return;
      await api.request(
        'PUT',
        '/notifications/devices',
        body: {'token': token},
      );
      if (!_current(id, version)) return;
      _token = token;
      _boundOwner = id;
    });
    _registration = pending;
    return pending;
  }

  Future<void> restore() async {
    if (busy) return;
    final id = owner(), version = api.sessionVersion;
    if (id == null) return;
    try {
      if (await storage.read(key: _key(id)) != 'true' ||
          !_current(id, version)) {
        return;
      }
      await enable(requestPermission: false);
    } catch (_) {
      if (_current(id, version)) {
        error = 'Chưa đọc được cài đặt thông báo trên thiết bị này.';
        _notify();
      }
    }
  }

  Future<void> enable({bool requestPermission = true}) async {
    if (busy || owner() == null) return;
    final id = owner()!, version = api.sessionVersion;
    busy = true;
    error = null;
    _notify();
    try {
      await _revocation;
      await _initialize();
      if (!_current(id, version)) return;
      if (requestPermission && !await gateway.requestPermission()) {
        throw const ApiException(
          'Thông báo chưa được cho phép. Bạn có thể bật trong cài đặt của điện thoại.',
        );
      }
      if (!_current(id, version)) return;
      final token = await gateway.token();
      if (!_current(id, version)) return;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Chưa lấy được mã thiết bị. Vui lòng thử lại.',
        );
      }
      await _register(token);
      if (!_current(id, version)) return;
      await storage.write(key: _key(id), value: 'true');
      if (!_current(id, version)) return;
      enabled = true;
      final initial = await gateway.initialEvent();
      if (_current(id, version) && initial != null) _receive(initial);
    } catch (e) {
      if (_current(id, version)) {
        error = '$e';
        enabled = false;
      }
    } finally {
      if (!_current(id, version) && _ready) {
        _revocation = gateway.deleteToken().catchError((Object _) {});
        await _revocation;
      }
      busy = false;
      _notify();
    }
  }

  Future<void> disable() async {
    if (busy) {
      throw const ApiException('Vui lòng đợi cập nhật thông báo hoàn tất.');
    }
    busy = true;
    error = null;
    _notify();
    try {
      await _registration.catchError((Object _) {});
      Object? unregisterError;
      if (_token != null && _boundOwner == owner()) {
        try {
          await api.request(
            'DELETE',
            '/notifications/devices',
            body: {'token': _token},
          );
        } catch (e) {
          unregisterError = e;
        }
      }
      // Revoking Firebase also invalidates any stale server-side token offline.
      if (_ready) await gateway.deleteToken();
      if (unregisterError != null && !_ready) throw unregisterError;
      if (owner() != null) await storage.delete(key: _key(owner()!));
      enabled = false;
      _token = null;
      _boundOwner = null;
      pendingOpen = null;
    } catch (e) {
      error = '$e';
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  void sessionCleared() {
    enabled = false;
    _boundOwner = null;
    pendingOpen = null;
    error = null;
    if (_ready) _revocation = gateway.deleteToken().catchError((Object _) {});
    _token = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tokens?.cancel();
    _messages?.cancel();
    _events.close();
    super.dispose();
  }
}

/// Accept customer destinations only; query values must never become arbitrary URLs.
({String kind, String id})? notificationDestination(Json data) {
  final target = Uri.tryParse('${data['target'] ?? ''}');
  if (target == null ||
      target.hasScheme ||
      target.hasAuthority ||
      target.fragment.isNotEmpty) {
    return null;
  }
  if (target.path == '/phan-hoi' || target.path == '/doi-tra') {
    final kind = target.path.substring(1);
    final id =
        target.queryParameters[kind == 'phan-hoi' ? 'feedbackId' : 'requestId'];
    if (id != null && RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      return (kind: kind, id: id);
    }
  }
  final path = target.pathSegments;
  if (path.length == 2 &&
      ['don-hang', 'phan-hoi', 'doi-tra'].contains(path.first) &&
      RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(path.last)) {
    return (kind: path.first, id: path.last);
  }
  return null;
}
