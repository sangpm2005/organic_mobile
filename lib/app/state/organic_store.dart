import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/organic_api.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/json.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/checkout/data/checkout_repository.dart';
import '../../features/orders/data/orders_repository.dart';
import '../../features/orders/domain/order_labels.dart';
import '../../features/rewards/data/rewards_repository.dart';
import '../../features/promotions/data/promotions_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/feedback/data/feedback_repository.dart';
import '../../features/returns/data/returns_repository.dart';
import '../../features/returns/data/pending_return_files.dart';
import '../../features/reviews/data/reviews_repository.dart';
import '../../core/media/upload_file.dart';
import '../../shared/media/media_validation.dart';
import '../../features/auth/data/google_auth_repository.dart';
import '../../features/auth/data/google_identity.dart';

class OrganicStore extends ChangeNotifier {
  final OrganicApi api;
  final FlutterSecureStorage storage;
  final ReturnDraftFiles returnDraftFiles;
  late final GoogleAuthRepository googleAuth;
  late final feedbackService = FeedbackRepository(api);
  late final returnsService = ReturnsRepository(api);
  late final reviewService = ReviewsRepository(api);
  Json? pendingReturn;
  Future<Json>? _returnPending;
  late final checkout = CheckoutRepository(api);
  late final orderService = OrdersRepository(api);
  late final rewardService = RewardsRepository(api);
  late final promotionService = PromotionsRepository(api);
  late final notificationService = NotificationsRepository(api);
  Json? pendingVoucherExchange;
  String selectedVoucherCode = '';
  String selectedPromotionCode = '';
  Future<Json>? _exchangePending;
  List<Json> publicOffers = [], inbox = [];
  Set<String> favorites = {};
  int _favoriteRevision = 0;
  Future<void> _favoriteSave = Future.value();
  int _inboxUnread = 0, _inboxPage = 0;
  bool hasMoreInbox = false, _active = true;
  Json? user, profile, cart, rewards, pendingCheckout;
  Json home = {};
  List<Json> categories = [];
  List<Json> orders = [], promotions = [], transactions = [];
  int _orderPage = 0;
  bool hasMoreOrders = false, loadingMoreOrders = false;
  Set<String> readUpdates = {};
  String? accountError;
  Timer? _timer;
  int _generation = 0, _cartRevision = 0;
  int? _refreshGeneration;
  bool _disposed = false;
  Future<void> _pendingSave = Future.value();
  Future<void>? _accountPending;
  OrganicStore({
    OrganicApi? api,
    FlutterSecureStorage? storage,
    ReturnDraftFiles? returnDraftFiles,
    GoogleIdentity? googleIdentity,
  }) : api = api ?? OrganicApi(),
       storage = storage ?? const FlutterSecureStorage(),
       returnDraftFiles = returnDraftFiles ?? ReturnDraftFiles() {
    googleAuth = GoogleAuthRepository(this.api, identity: googleIdentity);
    this.api.onSessionChanged = _saveSession;
  }
  bool get loggedIn => user != null && api.accessToken != null;
  bool get profileCompletionRequired =>
      loggedIn &&
      user?['profileCompletionRequired'] == true &&
      '${profile?['phoneNumber'] ?? user?['phoneNumber'] ?? ''}'.trim().isEmpty;
  int get cartCount => (cart?['totalQuantity'] as num?)?.toInt() ?? 0;
  List<Json> get cartItems => objects(cart?['items']);
  List<Product> get featured =>
      objects(home['featuredProducts']).map(Product.fromJson).toList();
  String updateKey(Json order) =>
      '${order['id']}:${order['status']}:${order['paymentStatus']}';
  List<Json> get updates =>
      [
        ...inbox.map(
          (n) => {
            ...n,
            'key': 'inbox:${n['id']}',
            'kind': 'inbox',
            'read': n['readAt'] != null,
          },
        ),
        ...orders.map(
          (o) => {
            'key': updateKey(o),
            'kind': 'order',
            'orderId': o['id'],
            'title': '${o['orderCode']}',
            'message':
                '${orderStatus(o['status'])} · ${orderStatus(o['paymentStatus'])}',
            'createdAt': o['orderedAt'],
            'read': readUpdates.contains(updateKey(o)),
          },
        ),
        ...promotions.map(
          (p) => {
            'key': 'promotion:${p['id']}:${p['startDate']}:${p['endDate']}',
            'kind': 'promotion',
            'title': p['name'],
            'message': p['description'] ?? 'Ưu đãi mới từ organicfood',
            'createdAt': p['startDate'],
            'read': readUpdates.contains(
              'promotion:${p['id']}:${p['startDate']}:${p['endDate']}',
            ),
          },
        ),
      ]..sort(
        (a, b) =>
            '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'),
      );
  int get unread => !loggedIn
      ? 0
      : _inboxUnread +
            updates
                .where((n) => n['kind'] != 'inbox' && n['read'] != true)
                .length;

  Future<void> initialize() async {
    try {
      final saved = await storage.read(key: 'moc.session.v1');
      if (saved != null) {
        final data = object(jsonDecode(saved));
        api.accessToken = data['accessToken'];
        api.refreshToken = data['refreshToken'];
        user = data['user'] == null ? null : object(data['user']);
        readUpdates = Set<String>.from(data['readUpdates'] ?? []);
        pendingCheckout = data['pendingCheckout'] == null
            ? null
            : object(data['pendingCheckout']);
        pendingVoucherExchange = data['pendingVoucherExchange'] == null
            ? null
            : object(data['pendingVoucherExchange']);
        pendingReturn = data['pendingReturn'] == null
            ? null
            : object(data['pendingReturn']);
      }
    } catch (_) {
      /* A fresh session also works when platform storage is unavailable. */
    }
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (loggedIn && _active) {
        unawaited(refreshAccount());
      }
    });
    await _loadFavorites();
    if (loggedIn) {
      unawaited(refreshAccount());
    }
  }

  Future<void> _saveSession({bool requirePersistence = false}) async {
    if (api.accessToken == null) {
      _clearAccount();
    }
    final snapshot = !loggedIn
        ? null
        : jsonEncode({
            'accessToken': api.accessToken,
            'refreshToken': api.refreshToken,
            'user': user,
            'readUpdates': readUpdates.toList(),
            'pendingCheckout': pendingCheckout,
            'pendingVoucherExchange': pendingVoucherExchange,
            'pendingReturn': pendingReturn,
          });
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      try {
        if (snapshot == null) {
          await storage.delete(key: 'moc.session.v1');
        } else {
          await storage.write(key: 'moc.session.v1', value: snapshot);
        }
      } catch (_) {
        if (requirePersistence) {
          throw const ApiException(
            'Chưa lưu được yêu cầu trên thiết bị. Lần thử này chưa được gửi; vui lòng thử lại.',
          );
        }
        /* Keep the current in-memory session when platform storage fails. */
      }
    });
    await _pendingSave;
    notifyListeners();
  }

  void _clearAccount() {
    final draft = pendingReturn;
    if (draft != null) {
      unawaited(
        returnDraftFiles.remove('${draft['key']}').catchError((Object _) {}),
      );
    }
    pendingReturn = null;
    _returnPending = null;
    _generation++;
    _cartRevision++;
    user = profile = cart = rewards = null;
    favorites = {};
    _favoriteRevision++;
    pendingCheckout = null;
    pendingVoucherExchange = null;
    _exchangePending = null;
    selectedVoucherCode = '';
    selectedPromotionCode = '';
    inbox = [];
    _inboxUnread = _inboxPage = 0;
    hasMoreInbox = false;
    orders = [];
    promotions = [];
    transactions = [];
    readUpdates = {};
    accountError = null;
    loadingMoreOrders = false;
    _orderPage = 0;
    hasMoreOrders = false;
  }

  Future<void> loadHome() async {
    home = object(await api.request('GET', '/home', authenticated: false));
    if (categories.isEmpty) categories = objects(home['categories']);
    notifyListeners();
    try {
      publicOffers = await promotionService.feed();
      notifyListeners();
    } catch (_) {
      // Home/catalog remain usable if the optional offers feed is unavailable.
    }
  }

  Future<void> loadCategories() async {
    categories = pageItems(
      await api.request(
        'GET',
        '/categories',
        authenticated: false,
        query: {'size': 100},
      ),
    ).map((c) => {...c, 'name': c['categoryName'] ?? c['name']}).toList();
    notifyListeners();
  }

  Future<List<Product>> products({
    String keyword = '',
    String? categoryId,
    int page = 0,
    String sortBy = 'createdAt',
    String direction = 'desc',
  }) async {
    return pageItems(
      await api.request(
        'GET',
        '/products',
        authenticated: false,
        query: {
          'keyword': keyword,
          'categoryId': categoryId,
          'page': page,
          'size': 20,
          'sortBy': sortBy,
          'direction': direction,
        },
      ),
    ).map(Product.fromJson).toList();
  }

  Future<void> login(String username, String password) async {
    final generation = _generation;
    final result = object(
      await api.request(
        'POST',
        '/auth/login',
        authenticated: false,
        body: {
          'username': username.trim(),
          'password': password,
          'rememberMe': true,
        },
      ),
    );
    await _acceptLogin(result, generation);
  }

  Future<bool> loginWithGoogle({bool Function()? isActive}) async {
    final generation = _generation;
    bool current() =>
        generation == _generation && !_disposed && (isActive?.call() ?? true);
    final result = await googleAuth.login(isCurrent: current);
    return result != null &&
        current() &&
        await _acceptLogin(result, generation);
  }

  Future<bool> linkGoogle(
    String currentPassword, {
    bool Function()? isActive,
  }) async {
    if (!loggedIn) throw const ApiException('Vui lòng đăng nhập trước.');
    final generation = _generation;
    final result = await googleAuth.link(
      currentPassword: currentPassword,
      isCurrent: () =>
          generation == _generation &&
          loggedIn &&
          !_disposed &&
          (isActive?.call() ?? true),
    );
    return result != null &&
        generation == _generation &&
        loggedIn &&
        !_disposed;
  }

  Future<bool> _acceptLogin(Json result, int generation) async {
    final info = object(result['user']);
    if (generation != _generation || _disposed) return false;
    if (!(info['roles'] as List? ?? []).any(
      (r) => '$r'.replaceFirst('ROLE_', '') == 'CUSTOMER',
    )) {
      throw const ApiException(
        'Ứng dụng dành cho khách hàng. Vui lòng dùng tài khoản CUSTOMER.',
      );
    }
    if (result['accessToken'] is! String ||
        (result['accessToken'] as String).isEmpty ||
        result['refreshToken'] is! String ||
        (result['refreshToken'] as String).isEmpty) {
      throw const ApiException('Máy chủ trả về phiên đăng nhập chưa hợp lệ.');
    }
    _clearAccount();
    user = info;
    api.setSession(result['accessToken'], result['refreshToken']);
    await _saveSession();
    await _loadFavorites();
    await refreshAccount();
    return true;
  }

  Future<void> logout() async {
    final revoke = api
        .request('POST', '/auth/logout')
        .then<void>((_) {}, onError: (Object _) {});
    api.setSession(null, null);
    _clearAccount();
    await _saveSession();
    try {
      await revoke;
    } catch (_) {
      /* Clear device session even offline. */
    }
  }

  Future<void> refreshAccount({bool force = false}) async {
    if (!loggedIn || _disposed) return;
    final generation = _generation;
    final running = _accountPending;
    if (running != null && _refreshGeneration == generation) {
      await running;
      if (force && generation == _generation && loggedIn) {
        await refreshAccount();
      }
      return;
    }
    final pending = _loadAccount();
    _accountPending = pending;
    try {
      await pending;
    } finally {
      if (identical(_accountPending, pending)) _accountPending = null;
    }
  }

  Future<void> _loadAccount() async {
    if (!loggedIn || _refreshGeneration == _generation || _disposed) {
      return;
    }
    final generation = _generation, cartRevision = _cartRevision;
    _refreshGeneration = generation;
    Future<(dynamic, Object?)> fetch(String path, {Json? query}) async {
      try {
        return (await api.request('GET', path, query: query), null);
      } catch (error) {
        return (null, error);
      }
    }

    try {
      final results = await Future.wait([
        fetch('/customers/me'),
        fetch('/cart'),
        fetch('/customers/me/rewards'),
        fetch('/orders', query: {'size': 20}),
        fetch('/promotions', query: {'size': 100}),
        fetch('/customers/me/reward-transactions', query: {'size': 100}),
        fetch('/inbox', query: {'size': 20}),
      ]);
      if (!loggedIn || generation != _generation || _disposed) {
        return;
      }
      if (results[0].$2 == null) profile = object(results[0].$1);
      if (results[1].$2 == null && cartRevision == _cartRevision) {
        cart = object(results[1].$1);
      }
      if (results[2].$2 == null) rewards = object(results[2].$1);
      if (results[3].$2 == null) {
        final recent = pageItems(results[3].$1);
        final recentIds = recent.map((o) => o['id']).toSet();
        orders = [
          ...recent,
          ...orders.where((o) => !recentIds.contains(o['id'])),
        ];
        hasMoreOrders =
            orders.length < number(object(results[3].$1)['totalElements']);
      }
      if (results[4].$2 == null) promotions = pageItems(results[4].$1);
      if (results[5].$2 == null) transactions = objects(results[5].$1);
      if (results[6].$2 == null) {
        final data = object(results[6].$1);
        final recent = pageItems(data['page']);
        final ids = recent.map((n) => n['id']).toSet();
        inbox = [...recent, ...inbox.where((n) => !ids.contains(n['id']))];
        _inboxUnread = number(data['unreadCount']).toInt();
        hasMoreInbox =
            inbox.length < number(object(data['page'])['totalElements']);
      }
      accountError = results
          .where((r) => r.$2 != null)
          .map((r) => '${r.$2}')
          .firstOrNull;
    } catch (error) {
      if (generation == _generation) {
        accountError = '$error';
      }
    } finally {
      if (_refreshGeneration == generation) _refreshGeneration = null;
      notifyListeners();
    }
  }

  Future<void> add(String variantId, int quantity) async {
    final generation = _generation, revision = ++_cartRevision;
    final result = object(
      await api.request(
        'POST',
        '/cart/items',
        body: {'variantId': variantId, 'quantity': quantity},
      ),
    );
    if (generation != _generation || revision != _cartRevision || !loggedIn) {
      return;
    }
    cart = result;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (!loggedIn || loadingMoreOrders || !hasMoreOrders) {
      return;
    }
    loadingMoreOrders = true;
    notifyListeners();
    final generation = _generation;
    try {
      final result = await api.request(
        'GET',
        '/orders',
        query: {'page': _orderPage + 1, 'size': 20},
      );
      if (generation != _generation || !loggedIn) {
        return;
      }
      final ids = orders.map((o) => o['id']).toSet();
      orders = [
        ...orders,
        ...pageItems(result).where((o) => !ids.contains(o['id'])),
      ];
      _orderPage++;
      hasMoreOrders = orders.length < number(object(result)['totalElements']);
    } finally {
      if (generation == _generation) loadingMoreOrders = false;
      notifyListeners();
    }
  }

  Future<void> quantity(String id, int value, {int? expectedQuantity}) async {
    final generation = _generation, revision = ++_cartRevision;
    final result = object(
      await api.request(
        value <= 0 ? 'DELETE' : 'PATCH',
        '/cart/items/$id',
        body: value <= 0 ? null : {'quantity': value},
        query: expectedQuantity == null
            ? null
            : {'expectedQuantity': expectedQuantity},
      ),
    );
    if (generation != _generation || revision != _cartRevision || !loggedIn) {
      return;
    }
    cart = result;
    notifyListeners();
  }

  Future<void> readOrder(Json order) async {
    readUpdates.add(updateKey(order));
    await _saveSession();
  }

  Future<void> savePendingCheckout(Json? value) async {
    pendingCheckout = value;
    await _saveSession();
  }

  void setActive(bool active) {
    _active = active;
    if (active && loggedIn) unawaited(refreshAccount());
  }

  Future<void> addBatch(List<Json> items) async {
    final generation = _generation, revision = ++_cartRevision;
    final result = object(
      await api.request('POST', '/cart/items/batch', body: {'items': items}),
    );
    if (generation != _generation || revision != _cartRevision || !loggedIn) {
      return;
    }
    cart = result;
    notifyListeners();
  }

  void selectVoucher(String code) {
    selectedVoucherCode = code.trim().toUpperCase();
    notifyListeners();
  }

  void selectPromotion(String code) {
    selectedPromotionCode = code.trim().toUpperCase();
    notifyListeners();
  }

  Future<Json> exchangeVoucher([Json? offer]) {
    if (_exchangePending != null) return _exchangePending!;
    final pending = _exchangeVoucher(offer);
    _exchangePending = pending;
    return pending.whenComplete(() {
      if (identical(_exchangePending, pending)) _exchangePending = null;
    });
  }

  Future<Json> _exchangeVoucher(Json? offer) async {
    if (!loggedIn) throw const ApiException('Vui lòng đăng nhập lại.');
    final generation = _generation;
    if (pendingVoucherExchange == null) {
      if (offer == null ||
          number(offer['pointsCost']) <= 0 ||
          '${offer['exchangeVersion'] ?? ''}'.isEmpty) {
        throw const ApiException('Ưu đãi đã thay đổi. Vui lòng tải lại.');
      }
      if (rewards == null ||
          number(rewards!['available']) < number(offer['pointsCost'])) {
        throw const ApiException('Chưa đủ điểm khả dụng để đổi voucher.');
      }
      pendingVoucherExchange = {
        'key': newIdempotencyKey(),
        'payload': {
          'promotionId': offer['id'],
          'expectedPointsCost': offer['pointsCost'],
          'expectedOfferVersion': offer['exchangeVersion'],
        },
      };
      await _saveSession();
    } else if (offer != null &&
        object(pendingVoucherExchange!['payload'])['promotionId'] !=
            offer['id']) {
      throw const ApiException(
        'Cần kiểm tra lần đổi voucher đang chờ trước khi đổi ưu đãi khác.',
      );
    }
    if (generation != _generation || !loggedIn) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.');
    }
    final pending = pendingVoucherExchange!;
    try {
      final voucher = await rewardService.exchange(
        object(pending['payload']),
        '${pending['key']}',
      );
      if (generation != _generation || !loggedIn) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      pendingVoucherExchange = null;
      await _saveSession();
      await refreshAccount(force: true);
      return voucher;
    } on ApiException catch (error) {
      final status = error.status;
      if (generation == _generation &&
          status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429) {
        pendingVoucherExchange = null;
        await _saveSession();
      }
      rethrow;
    }
  }

  Future<void> readUpdate(Json update) async {
    final generation = _generation;
    if (update['kind'] == 'inbox') {
      await notificationService.read('${update['id']}');
      if (generation != _generation || !loggedIn) return;
      inbox = inbox
          .map(
            (n) => n['id'] == update['id']
                ? {...n, 'readAt': DateTime.now().toIso8601String()}
                : n,
          )
          .toList();
      if (update['read'] != true && _inboxUnread > 0) _inboxUnread--;
    } else {
      readUpdates.add('${update['key']}');
      if (readUpdates.length > 200) readUpdates.remove(readUpdates.first);
    }
    await _saveSession();
  }

  Future<void> loadMoreInbox() async {
    final generation = _generation;
    final data = await notificationService.page(_inboxPage + 1);
    if (generation != _generation || !loggedIn) return;
    final ids = inbox.map((n) => n['id']).toSet();
    inbox = [
      ...inbox,
      ...pageItems(data['page']).where((n) => !ids.contains(n['id'])),
    ];
    _inboxPage++;
    _inboxUnread = number(data['unreadCount']).toInt();
    hasMoreInbox = inbox.length < number(object(data['page'])['totalElements']);
    notifyListeners();
  }

  String get _favoriteKey =>
      'organicfood.favorites.v1.${base64Url.encode(utf8.encode('${user?['accountId'] ?? user?['username'] ?? 'guest'}'))}';
  Future<void> _loadFavorites() async {
    final generation = _generation,
        revision = _favoriteRevision,
        key = _favoriteKey;
    try {
      final raw = await storage.read(key: key);
      if (generation != _generation || revision != _favoriteRevision) return;
      favorites = Set<String>.from(raw == null ? [] : jsonDecode(raw));
      notifyListeners();
    } catch (_) {
      /* Keep in-memory favorites if storage is unavailable. */
    }
  }

  Future<void> toggleFavorite(String id) async {
    if (!favorites.contains(id) && favorites.length >= 200) {
      throw const ApiException('Bạn đã lưu tối đa 200 sản phẩm.');
    }
    _favoriteRevision++;
    if (!favorites.remove(id)) favorites.add(id);
    final key = _favoriteKey, value = jsonEncode(favorites.toList());
    notifyListeners();
    _favoriteSave = _favoriteSave
        .catchError((Object _) {})
        .then((_) => storage.write(key: key, value: value));
    await _favoriteSave;
  }

  Future<Json> submitReturn({Json? payload, List<UploadFile>? files}) {
    if (_returnPending != null) return _returnPending!;
    final pending = _submitReturn(payload, files);
    _returnPending = pending;
    return pending.whenComplete(() {
      if (identical(_returnPending, pending)) _returnPending = null;
    });
  }

  Future<Json> _submitReturn(Json? payload, List<UploadFile>? files) async {
    if (!loggedIn) throw const ApiException('Vui lòng đăng nhập lại.');
    final generation = _generation;
    if (pendingReturn == null) {
      if (payload == null || files == null) {
        throw const ApiException('Chưa có yêu cầu để gửi.');
      }
      validateMedia(files, imagesOnly: true, required: true);
      final key = newIdempotencyKey();
      try {
        await returnDraftFiles.put(key, files);
      } catch (_) {
        throw const ApiException(
          'Chưa lưu được ảnh minh chứng trên thiết bị. Yêu cầu chưa được gửi.',
        );
      }
      if (generation != _generation || !loggedIn) {
        await returnDraftFiles.remove(key);
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      pendingReturn = {'key': key, 'payload': jsonDecode(jsonEncode(payload))};
    } else if (payload != null &&
        jsonEncode(object(pendingReturn!['payload'])) != jsonEncode(payload)) {
      throw const ApiException(
        'Cần kiểm tra yêu cầu đang chờ trước khi gửi nội dung mới.',
      );
    }
    if (generation != _generation || !loggedIn) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.');
    }
    await _saveSession(requirePersistence: true);
    if (generation != _generation || !loggedIn) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.');
    }
    final pending = pendingReturn!, key = '${pendingReturn!['key']}';
    final attachments = await returnDraftFiles.read(key);
    if (generation != _generation || !loggedIn) {
      throw const ApiException('Phiên đăng nhập đã thay đổi.');
    }
    try {
      final result = await returnsService.create(
        object(pending['payload']),
        attachments,
        key,
      );
      if (generation != _generation || !loggedIn) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      pendingReturn = null;
      await _saveSession();
      try {
        await returnDraftFiles.remove(key);
      } catch (_) {
        /* Do not retry a confirmed request because local cleanup failed. */
      }
      if (generation != _generation || !loggedIn) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      return result;
    } on ApiException catch (e) {
      if (generation == _generation &&
          e.status != null &&
          e.status! >= 400 &&
          e.status! < 500 &&
          ![408, 429].contains(e.status)) {
        pendingReturn = null;
        await _saveSession();
        try {
          await returnDraftFiles.remove(key);
        } catch (_) {
          /* Private cache cleanup can be retried later. */
        }
      }
      rethrow;
    }
  }

  static String newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    api.close();
    super.dispose();
  }
}
