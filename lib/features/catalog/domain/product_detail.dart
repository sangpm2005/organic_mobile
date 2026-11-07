import 'package:intl/intl.dart';

import '../../../core/utils/json.dart';

// A product owns its sizes. Cart and stock requests always use the selected
// variant ID, rather than creating a separate product for each size.
List<Json> sellableVariants(Json product) =>
    objects(product['variants'])
        .where(
          (v) =>
              v['id'] != null &&
              v['status'] == 'active' &&
              number(v['sellingPrice']) > 0 &&
              number(v['netQuantity']) > 0,
        )
        .toList()
      ..sort(
        (a, b) =>
            number(a['sellingPrice']).compareTo(number(b['sellingPrice'])),
      );

String variantDisplayName(Json variant) {
  final name = '${variant['variantName'] ?? ''}'.trim();
  final quantity = number(variant['netQuantity']);
  final unit = '${variant['unitId'] ?? ''}'.trim();
  if (quantity <= 0 ||
      unit.isEmpty ||
      RegExp(
        r'\d\s*(?:[.,]\d+)?\s*(?:kg|g|ml|l)\b',
        caseSensitive: false,
      ).hasMatch(name)) {
    return name;
  }
  final size = '${NumberFormat.decimalPattern('vi_VN').format(quantity)} $unit';
  return name.isEmpty ? size : '$name · $size';
}

class ProductImage {
  final String url, alt;
  const ProductImage(this.url, this.alt);
}

List<ProductImage> productImages(Json product, {String? baseUrl}) {
  final images = objects(product['images']);
  final ordered = images.indexed.toList()
    ..sort((a, b) {
      final primary = (b.$2['isPrimary'] == true ? 1 : 0).compareTo(
        a.$2['isPrimary'] == true ? 1 : 0,
      );
      final order = number(a.$2['sortOrder'])
          .compareTo(number(b.$2['sortOrder']));
      return primary != 0
          ? primary
          : order != 0
          ? order
          : a.$1.compareTo(b.$1);
    });
  final source = ordered.map((entry) => entry.$2).toList();
  if (source.isEmpty && product['imageUrl'] != null) {
    source.add({'imageUrl': product['imageUrl']});
  }
  final seen = <String>{};
  final result = <ProductImage>[];
  for (final item in source) {
    final raw = '${item['imageUrl'] ?? ''}'.trim();
    var uri = Uri.tryParse(raw);
    if (raw.startsWith('/') && !raw.startsWith('//') && baseUrl != null) {
      uri = Uri.parse(baseUrl).resolve(raw);
    }
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !seen.add(uri.toString())) {
      continue;
    }
    final alt = '${item['altText'] ?? ''}'.trim();
    result.add(
      ProductImage(
        uri.toString(),
        alt.isNotEmpty
            ? alt
            : '${product['productName'] ?? 'Sản phẩm'} · ảnh ${result.length + 1}',
      ),
    );
  }
  return result;
}
