import '../../../core/utils/json.dart';

/// Matches the customer's selection identity used by the web and backend.
String saleKey(Json item) {
  final supplied = '${item['selectionKey'] ?? ''}';
  if (supplied.isNotEmpty) return supplied;
  final variant = '${item['variantId'] ?? ''}';
  final expiry = '${item['expiryDate'] ?? ''}';
  return expiry.isEmpty
      ? variant
      : '$variant~$expiry~${item['salePromotionId'] ?? item['promotionId'] ?? ''}';
}

Json saleFields(Json? item) {
  if (item == null || '${item['expiryDate'] ?? ''}'.isEmpty) return {};
  return {
    'expiryDate': item['expiryDate'],
    'salePromotionId': item['salePromotionId'] ?? item['promotionId'],
  };
}

Json saleItem(Json item) => {
  'variantId': item['variantId'],
  'quantity': item['quantity'],
  ...saleFields(item),
};

bool supportsSaleChoices(Json? availability) =>
    availability?['saleOptions'] is List;

List<Json> saleChoices(Json? availability, String? variantId) =>
    objects(availability?['saleOptions'])
        .where(
          (option) =>
              option['variantId'] == variantId &&
              number(option['availableQuantity']) > 0,
        )
        .toList();

Json? selectedSale(List<Json> choices, String? key) =>
    choices.where((option) => saleKey(option) == key).firstOrNull;

/// A storefront SKU has one current offer. Explicit dates in existing carts stay untouched.
Json? currentSaleChoice(List<Json> choices) {
  final direct = choices
      .where((o) => o['combo'] != true && number(o['availableQuantity']) > 0)
      .toList();
  final campaigns =
      direct.where((o) => '${o['promotionId'] ?? ''}'.isNotEmpty).toList()
        ..sort((a, b) {
          final date = '${a['expiryDate']}'.compareTo('${b['expiryDate']}');
          if (date != 0) return date;
          final price = number(a['price']).compareTo(number(b['price']));
          return price != 0 ? price : saleKey(a).compareTo(saleKey(b));
        });
  if (campaigns.isNotEmpty) return campaigns.first;
  final ordinary = direct
      .where((o) => '${o['promotionId'] ?? ''}'.isEmpty)
      .toList();
  if (ordinary.isEmpty) return null;
  final dates =
      ordinary
          .map((o) => '${o['nearestExpiryDate'] ?? o['expiryDate'] ?? ''}')
          .where((d) => d.isNotEmpty)
          .toList()
        ..sort();
  return {
    ...ordinary.first,
    'selectionKey': ordinary.first['variantId'],
    'expiryDate': null,
    'promotionId': null,
    'nearestExpiryDate': dates.firstOrNull,
    'availableQuantity': ordinary.fold<int>(
      0,
      (sum, o) => sum + number(o['availableQuantity']).toInt(),
    ),
  };
}

String saleDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '$value';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
