import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';
import '../domain/payment_policy.dart';

class OrdersRepository {
  final OrganicApi api;
  OrdersRepository(this.api);

  /// The current API only paginates. Search must include older pages too.
  Future<List<Json>> all() async {
    final session = api.sessionVersion;
    final rows = <String, Json>{};
    for (var page = 0; ; page++) {
      final result = object(
        await api.request('GET', '/orders', query: {'page': page, 'size': 100}),
      );
      if (api.sessionVersion != session) {
        throw StateError('Phiên đăng nhập đã thay đổi.');
      }
      final batch = pageItems(result);
      final previous = rows.length;
      for (final row in batch) {
        rows['${row['id']}'] = row;
      }
      if (rows.length >= number(result['totalElements']) ||
          (result['totalPages'] != null &&
              page + 1 >= number(result['totalPages']))) {
        break;
      }
      if (previous == rows.length) {
        throw StateError('Danh sách đơn đã thay đổi. Vui lòng tìm lại.');
      }
    }
    return rows.values.toList();
  }

  Future<Json> detail(String id) async =>
      object(await api.request('GET', '/orders/${Uri.encodeComponent(id)}'));

  /// Reconcile an existing attempt only; never create a new charge during polling.
  Future<void> reconcile(Json order) async {
    if (!canPayOrder(order) || order['paymentMethod'] == 'cod') return;
    final version = api.sessionVersion;
    final payment = objects(order['payments'])
        .where(
          (p) =>
              p['gateway'] == order['paymentMethod'] &&
              ['pending', 'capturing'].contains(p['status']),
        )
        .firstOrNull;
    if (payment == null) return;
    final checked = await sync('${payment['id']}');
    if (version != api.sessionVersion) return;
    if (checked['gateway'] == 'paypal' &&
        ['pending', 'capturing'].contains(checked['status'])) {
      // PayPal still requires the buyer's approval in its own payment portal.
      await capturePaypal('${payment['id']}');
    }
  }

  Future<Json> cancel(String id) async => object(
    await api.request(
      'POST',
      '/orders/${Uri.encodeComponent(id)}/cancel',
      timeout: const Duration(seconds: 120),
    ),
  );
  Future<Json> initiate(String orderId, String gateway) async => object(
    await api.request(
      'POST',
      '/payments/initiate',
      body: {'orderId': orderId, 'gateway': gateway},
      timeout: const Duration(seconds: 60),
    ),
  );
  Future<Json> sync(String id) async => object(
    await api.request(
      'POST',
      '/payments/${Uri.encodeComponent(id)}/sync',
      timeout: const Duration(seconds: 60),
    ),
  );
  Future<Json> capturePaypal(String id) async => object(
    await api.request(
      'POST',
      '/payments/${Uri.encodeComponent(id)}/paypal/capture',
      timeout: const Duration(seconds: 60),
    ),
  );
}
