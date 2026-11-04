import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) =>
    value is List ? value.map(object).toList() : [];
List<Json> pageItems(dynamic value) => value is List
    ? objects(value)
    : objects(object(value)['items'] ?? object(value)['content']);
double number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String money(dynamic value) =>
    '${NumberFormat.decimalPattern('vi_VN').format(number(value))} đ';
String dateText(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null ? '—' : DateFormat('dd/MM/yyyy · HH:mm').format(parsed);
}

String orderStatus(dynamic status) =>
    const {
      'pending_payment': 'Chờ thanh toán',
      'confirmed': 'Đã xác nhận',
      'paid': 'Đã thanh toán',
      'preparing': 'Đang chuẩn bị',
      'shipping': 'Đang giao hàng',
      'shipped': 'Đang giao hàng',
      'delivered': 'Đã giao hàng',
      'completed': 'Hoàn tất',
      'cancelled': 'Đã hủy',
      'expired': 'Hết thời gian',
      'pending': 'Đang xử lý',
      'failed': 'Thất bại',
    }[status] ??
    '$status';

class Product {
  final String id, name, category, image, slug;
  final String? variantId, variantName;
  final double price, comparePrice;
  final bool verified;
  Product.fromJson(Json data)
    : id = '${data['id']}',
      name = '${data['productName'] ?? data['name'] ?? ''}',
      category = '${data['categoryName'] ?? ''}',
      image = '${data['imageUrl'] ?? ''}',
      slug = '${data['slug'] ?? ''}',
      variantId = data['defaultVariantId']?.toString(),
      variantName = data['defaultVariantName']?.toString(),
      price = number(data['defaultPrice'] ?? data['minPrice']),
      comparePrice = number(data['compareAtPrice']),
      verified = data['organicVerified'] == true;
}

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}
