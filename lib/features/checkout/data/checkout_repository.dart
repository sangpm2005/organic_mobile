import '../../../core/network/organic_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

class CheckoutRepository {
  final OrganicApi api;
  CheckoutRepository(this.api);

  Future<Json> methods() async =>
      object(await api.request('GET', '/payments/methods'));
  Future<Json> preview(Json payload) async {
    final voucher = '${payload['voucherCode'] ?? ''}'.trim().toUpperCase();
    if (voucher.isNotEmpty && number(payload['points']) > 0) {
      throw const ApiException('Chọn dùng voucher hoặc trừ điểm trực tiếp.');
    }
    final quote = object(
      await api.request('POST', '/checkout/preview', body: payload),
    );
    if (voucher.isNotEmpty &&
        ('${quote['voucherCode'] ?? ''}'.toUpperCase() != voucher ||
            number(quote['voucherDiscount']) <= 0)) {
      throw const ApiException(
        'Voucher chưa được áp dụng. Vui lòng kiểm tra điều kiện trước khi đặt hàng.',
      );
    }
    return quote;
  }

  Future<Json> place(Json payload, String key) async => object(
    await api.request('POST', '/orders', body: payload, idempotencyKey: key),
  );
  Future<List<Json>> locations(String address) async => objects(
    await api.request(
      'GET',
      '/checkout/delivery-locations',
      query: {'address': address},
    ),
  );
  Future<Json> fromMap(String url) async => object(
    await api.request(
      'POST',
      '/checkout/delivery-location-from-map',
      body: {'url': url},
    ),
  );
}
