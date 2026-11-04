import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

class OrdersRepository {
  final OrganicApi api;
  OrdersRepository(this.api);
  Future<Json> detail(String id) async =>
      object(await api.request('GET', '/orders/${Uri.encodeComponent(id)}'));
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
