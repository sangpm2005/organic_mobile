import '../../../core/utils/json.dart';

List<Json> shoppingCategories(dynamic source) {
  final rows =
      objects(source)
          .where(
            (category) =>
                number(category['productCount']) > 0 &&
                !'${category['name'] ?? category['categoryName'] ?? ''} ${category['code'] ?? category['categoryCode'] ?? ''}'
                    .toLowerCase()
                    .contains('combo'),
          )
          .toList()
        ..sort((a, b) {
          final count = number(b['productCount'])
              .compareTo(number(a['productCount']));
          return count != 0
              ? count
              : '${a['name'] ?? a['categoryName']}'.compareTo(
                  '${b['name'] ?? b['categoryName']}',
                );
        });
  return rows.take(8).toList();
}

Future<List<Json>> homeCategoryImages(
  Json home,
  Future<List<Json>> Function(String categoryId) fetch,
) async {
  final products = [
    ...objects(home['featuredProducts']),
    ...objects(home['newProducts']),
    ...objects(home['certifiedProducts']),
    ...objects(home['discountedProducts']),
  ];
  return Future.wait(
    shoppingCategories(home['categories']).map((category) async {
      var image = '${category['imageUrl'] ?? ''}'.trim();
      if (image.isEmpty) {
        image =
            '${products.where((p) => p['categoryId'] == category['id'] && '${p['imageUrl'] ?? ''}'.trim().isNotEmpty).firstOrNull?['imageUrl'] ?? ''}';
      }
      if (image.isEmpty) {
        try {
          image =
              '${(await fetch('${category['id']}')).firstOrNull?['imageUrl'] ?? ''}';
        } catch (_) {
          // Category discovery remains usable if optional images cannot load.
        }
      }
      return {...category, if (image.isNotEmpty) 'imageUrl': image};
    }),
  );
}

Map<String, List<Json>> homeCollections(Json home) {
  List<Json> distinct(Iterable<Json> rows) {
    final seen = <String>{};
    return rows
        .where((p) => '${p['id'] ?? ''}'.isNotEmpty && seen.add('${p['id']}'))
        .toList();
  }

  final discounted = objects(home['discountedProducts'])
      .where(
        (p) =>
            number(p['minPrice'] ?? p['defaultPrice']) > 0 &&
            number(p['compareAtPrice']) >
                number(p['minPrice'] ?? p['defaultPrice']),
      )
      .map((p) => '${p['id']}')
      .toSet();
  List<Json> group(Iterable<Json> rows) {
    final all = distinct(rows);
    final withoutDiscounts = all
        .where((p) => !discounted.contains('${p['id']}'))
        .toList();
    return withoutDiscounts.length >= 4 ? withoutDiscounts : all;
  }

  return {
    'available': group([
      ...objects(home['featuredProducts']),
      ...objects(home['newProducts']),
      ...objects(home['certifiedProducts']),
    ]),
    'featured': group(objects(home['featuredProducts'])),
    'newest': group(objects(home['newProducts'])),
    'certified': group(objects(home['certifiedProducts'])),
  };
}
