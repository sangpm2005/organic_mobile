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
