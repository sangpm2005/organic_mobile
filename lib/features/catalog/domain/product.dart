import '../../../core/utils/json.dart';

class ProductPage {
  final List<Product> items;
  final int total, pages;
  ProductPage.fromJson(dynamic data)
    : items = pageItems(data).map(Product.fromJson).toList(),
      total = number(object(data)['totalElements']).toInt(),
      pages = number(object(data)['totalPages']).toInt();
}

class Product {
  final String id, name, category, image, slug;
  final String? variantId, variantName;
  final double price, comparePrice;
  final bool verified;
  final Json sale;
  Product.fromJson(Json data)
    : id = '${data['id']}',
      name = '${data['productName'] ?? data['name'] ?? ''}',
      category = '${data['categoryName'] ?? ''}',
      image = '${data['imageUrl'] ?? ''}',
      slug = '${data['slug'] ?? ''}',
      variantId = data['defaultVariantId']?.toString(),
      variantName = (data['defaultVariantName'] ?? data['unit'])?.toString(),
      price = number(data['defaultPrice'] ?? data['minPrice']),
      comparePrice = number(data['compareAtPrice']),
      verified = data['organicVerified'] == true,
      sale = {
        'variantId': data['defaultVariantId'],
        if (data['expiryDate'] != null) 'expiryDate': data['expiryDate'],
        if (data['salePromotionId'] != null)
          'salePromotionId': data['salePromotionId'],
        if (data['selectionKey'] != null) 'selectionKey': data['selectionKey'],
      };
}
