import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

/// Keeps the backend's anonymous cart identity across app restarts. Only cart
/// requests receive this cookie; GET /cart merges it into the signed-in cart.
class CartRepository {
  final OrganicApi api;
  final FlutterSecureStorage storage;
  String? _cookie;
  Future<void> _tail = Future.value();
  CartRepository(this.api, this.storage);

  String get _key =>
      'organicfood.cart.v1.${base64Url.encode(utf8.encode(api.baseUrl))}';
  bool get hasGuestCart => _cookie != null;

  Future<void> restore() async {
    final value = await storage.read(key: _key);
    if (value != null && RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value)) {
      _cookie = value;
    }
  }

  Future<Json> request(
    String method, [
    String path = '',
    Json? body,
    Json? query,
  ]) {
    final version = api.sessionVersion;
    Future<Json> send() async {
      if (version != api.sessionVersion) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      var changed = false;
      final data = object(
        await api.request(
          method,
          '/cart$path',
          body: body,
          query: query,
          followRedirects: false,
          headers: {if (_cookie != null) 'Cookie': 'organic_cart=$_cookie'},
          onResponseHeaders: (headers) {
            if (version != api.sessionVersion) return;
            final match = RegExp(r'(?:^|,\s*)organic_cart=([^;]*)([^,]*)')
                .firstMatch(headers['set-cookie'] ?? '');
            if (match == null) return;
            if (RegExp(
                  r';\s*secure(?:;|$)',
                  caseSensitive: false,
                ).hasMatch(match.group(2)!) &&
                Uri.parse(api.baseUrl).scheme != 'https') {
              throw const ApiException(
                'Giỏ hàng cần kết nối HTTPS tới máy chủ.',
              );
            }
            final token = match.group(1)!;
            if (token.isEmpty ||
                RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
              _cookie = token.isEmpty ? null : token;
              changed = true;
            }
          },
        ),
      );
      if (changed) {
        if (_cookie == null) {
          await storage.delete(key: _key);
        } else {
          await storage.write(key: _key, value: _cookie);
        }
      }
      return data;
    }

    // Only guest operations/merges need serialization to share the first
    // issued cookie. A slow customer poll must not block cart mutations.
    final serialized = api.accessToken == null || _cookie != null;
    final result = serialized
        ? _tail.catchError((Object _) {}).then((_) => send())
        : send();
    if (serialized) _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
