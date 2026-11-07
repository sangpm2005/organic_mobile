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
      final columns =
          constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(12) > 18
          ? 1
          : constraints.maxWidth > 650
          ? 3
          : 2;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (var start = 0; start < products.length; start += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var offset = 0; offset < columns; offset++) ...[
                      if (offset > 0) const SizedBox(width: 12),
                      Expanded(
                        child: start + offset >= products.length
                            ? const SizedBox()
                            : ProductTile(
                                products[start + offset],
                                key: ValueKey(
                                  'product.tile.${products[start + offset].id}',
                                ),
                                onTap: () => onTap(products[start + offset]),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
