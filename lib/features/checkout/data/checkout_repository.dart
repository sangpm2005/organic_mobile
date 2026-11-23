import '../../../core/network/organic_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../../catalog/domain/sale_selection.dart';

class CheckoutRepository {
  final OrganicApi api;
  CheckoutRepository(this.api);

  static Json? coordinates(String text) {
    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$')
        .firstMatch(text);
    if (match == null) return null;
    final lat = double.parse(match[1]!), lng = double.parse(match[2]!);
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return {
      'label': 'Vị trí bạn đã chọn',
      'latitude': lat,
      'longitude': lng,
      'precise': true,
    };
  }

  Future<List<Json>> resolve(String text) async {
    final point = coordinates(text);
    if (point != null) return [point];
    if (Uri.tryParse(text)?.hasScheme == true) return [await fromMap(text)];
    return locations(text);
  }

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
    for (final item in objects(
      payload['items'],
    ).where((i) => i['expiryDate'] != null)) {
      final matches = objects(quote['items'])
          .where((line) => saleKey(line) == saleKey(item))
          .toList();
      if (matches.length != 1 ||
          number(matches.single['quantity']) != number(item['quantity'])) {
        throw const ApiException(
          'Hạn sử dụng hoặc ưu đãi đã thay đổi. Vui lòng kiểm tra lại lựa chọn trong giỏ hàng.',
          409,
        );
      }
    }
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
