import '../../../core/utils/json.dart';

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
