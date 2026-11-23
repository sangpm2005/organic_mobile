import 'dart:async';

import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

/// Shared per API client, maximum three concurrent public stock reads.
class ProductStockCache {
  static final _instances = Expando<ProductStockCache>();
  static ProductStockCache forApi(OrganicApi api) =>
      _instances[api] ??= ProductStockCache(api);
  final OrganicApi api;
  ProductStockCache(this.api);
  final _cache = <String, (DateTime, Json)>{};
  final _pending = <String, Future<Json>>{};
  final _waiters = <Completer<void>>[];
  int _active = 0;
  void invalidate(String id) => _cache.remove(id);
  Future<Json> get(String id, {bool fresh = false}) {
    if (fresh) invalidate(id);
    final cached = _cache[id];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(seconds: 30)) {
      return Future.value(cached.$2);
    }
    return _pending[id] ??= _read(id);
  }

  Future<Json> _read(String id) async {
    if (_active >= 3) {
      final gate = Completer<void>();
      _waiters.add(gate);
      await gate.future;
    } else {
      _active++;
    }
    try {
      final result = object(
        await api.request(
          'GET',
          '/products/${Uri.encodeComponent(id)}/availability',
          authenticated: false,
        ),
      );
      if (_cache.length >= 128) _cache.remove(_cache.keys.first);
      _cache[id] = (DateTime.now(), result);
      return result;
    } finally {
      _pending.remove(id);
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }
}
