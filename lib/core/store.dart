import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'models.dart';

class OrganicStore extends ChangeNotifier {
  final OrganicApi api;
  final FlutterSecureStorage storage;
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
  OrganicStore({OrganicApi? api, FlutterSecureStorage? storage})
    : api = api ?? OrganicApi(),
      storage = storage ?? const FlutterSecureStorage() {
    this.api.onSessionChanged = _saveSession;
  }
  bool get loggedIn => user != null && api.accessToken != null;
  int get cartCount => (cart?['totalQuantity'] as num?)?.toInt() ?? 0;
  List<Json> get cartItems => objects(cart?['items']);
  List<Product> get featured =>
      objects(home['featuredProducts']).map(Product.fromJson).toList();
  String updateKey(Json order) =>
      '${order['id']}:${order['status']}:${order['paymentStatus']}';
  int get unread =>
      orders.where((order) => !readUpdates.contains(updateKey(order))).length;

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
      }
    } catch (_) {
      /* A fresh session also works when platform storage is unavailable. */
    }
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (loggedIn) {
        unawaited(refreshAccount());
      }
    });
    if (loggedIn) {
      unawaited(refreshAccount());
    }
  }

  Future<void> _saveSession() async {
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
          });
    _pendingSave = _pendingSave.then((_) async {
      try {
        if (snapshot == null) {
          await storage.delete(key: 'moc.session.v1');
        } else {
          await storage.write(key: 'moc.session.v1', value: snapshot);
        }
      } catch (_) {
        /* Keep the current in-memory session when platform storage fails. */
      }
    });
    await _pendingSave;
    notifyListeners();
  }

  void _clearAccount() {
    _generation++;
    _cartRevision++;
    user = profile = cart = rewards = null;
    pendingCheckout = null;
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
    final info = object(result['user']);
    if (generation != _generation || _disposed) return;
    if (!(info['roles'] as List? ?? []).any(
      (r) => '$r'.replaceFirst('ROLE_', '') == 'CUSTOMER',
    )) {
      throw const ApiException(
        'Ứng dụng dành cho khách hàng. Vui lòng dùng tài khoản CUSTOMER.',
      );
    }
    _clearAccount();
    user = info;
    api.setSession(result['accessToken'], result['refreshToken']);
    await _saveSession();
    await refreshAccount();
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
