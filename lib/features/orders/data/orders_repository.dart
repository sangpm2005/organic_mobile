import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';
import '../domain/payment_policy.dart';

class OrdersRepository {
  final OrganicApi api;
  OrdersRepository(this.api);
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
