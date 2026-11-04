import 'package:flutter/material.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_tile.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onTap;
  const ProductGrid(this.products, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.maxWidth > 650 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: 290,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => ProductTile(
          products[i],
          key: ValueKey('product.tile.${products[i].id}'),
          onTap: () => onTap(products[i]),
        ),
      );
    },
  );
}
