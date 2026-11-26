import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../../catalog/domain/product.dart';
import '../../../catalog/presentation/product_screen.dart';
import '../../../catalog/presentation/widgets/product_grid.dart';
import '../../domain/home_merchandising.dart';

class HomeCollections extends StatefulWidget {
  final Json home;
  const HomeCollections({super.key, required this.home});
  @override
  State<HomeCollections> createState() => _HomeCollectionsState();
}

class _HomeCollectionsState extends State<HomeCollections> {
  String group = 'available', category = '';
  static const labels = {
    'available': 'Sản phẩm còn hàng',
    'featured': 'organicfood chọn lọc',
    'newest': 'Mới tại cửa hàng',
    'certified': 'Có chứng nhận hợp lệ',
  };
  @override
  Widget build(BuildContext context) {
    final groups = homeCollections(widget.home)
      ..removeWhere((_, rows) => rows.isEmpty);
    if (groups.isEmpty) return const SizedBox.shrink();
    final current = groups.containsKey(group) ? group : groups.keys.first;
    final rows = groups[current]!;
    final categories = objects(widget.home['categories'])
        .where((c) => rows.any((p) => p['categoryId'] == c['id']))
        .toList();
    final selectedCategory = categories.any((c) => '${c['id']}' == category)
        ? category
        : '';
    final products = rows
        .where(
          (p) =>
              selectedCategory.isEmpty ||
              '${p['categoryId']}' == selectedCategory,
        )
        .take(8)
        .map(Product.fromJson)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              for (final key in groups.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('home.group.$key'),
                    label: Text(labels[key]!),
                    selected: current == key,
                    onSelected: (_) => setState(() {
                      group = key;
                      category = '';
                    }),
                  ),
                ),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: DropdownButtonFormField<String>(
              key: ValueKey('home.category.$current.$selectedCategory'),
              initialValue: selectedCategory,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Lọc theo danh mục'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tất cả danh mục'),
                ),
                for (final c in categories)
                  DropdownMenuItem(
                    value: '${c['id']}',
                    child: Text('${c['name'] ?? c['categoryName'] ?? ''}'),
                  ),
              ],
              onChanged: (value) => setState(() => category = value ?? ''),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Text(
            '${products.length} sản phẩm',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ),
        ProductGrid(
          products,
          onTap: (p) => open(context, ProductScreen(p.id, initialSale: p.sale)),
        ),
      ],
    );
  }
}
