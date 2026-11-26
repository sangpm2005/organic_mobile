import '../../../core/utils/json.dart';

Json? initialComboVariant(Json product) {
  final variants = objects(product['variants']);
  return variants
          .where(
            (v) =>
                number(v['availableQuantity']) >=
                number(product['requiredQuantity']),
          )
          .firstOrNull ??
      variants.firstOrNull;
}

/// Display estimate only. Checkout remains authoritative for price and eligibility.
({double subtotal, double discount, double total})? comboEstimate(
  Json offer,
  Json? Function(Json) variant,
) {
  final products = objects(offer['products']);
  if (products.isEmpty) return null;
  double subtotal = 0;
  for (final product in products) {
    final selected = variant(product);
    final price = double.tryParse('${selected?['price']}');
    final quantity = number(product['requiredQuantity']);
    if (price == null || !price.isFinite || price < 0 || quantity <= 0) {
      return null;
    }
    subtotal += price * quantity;
  }
  double discount = 0;
  if (subtotal >= number(offer['minOrderValue'])) {
    discount = offer['discountType'] == 'percentage'
        ? (subtotal * number(offer['discountValue']) / 100).roundToDouble()
        : number(offer['discountValue']);
    if (offer['maxDiscountAmount'] != null) {
      discount = discount.clamp(
        0,
        number(offer['maxDiscountAmount']).clamp(0, double.infinity),
      );
    }
  }
  discount = discount.clamp(0, subtotal);
  return (subtotal: subtotal, discount: discount, total: subtotal - discount);
}
