import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductTile(this.product, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ProductPhoto(product.image),
                  ),
                  if (product.verified)
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✓ Hữu cơ',
                          style: TextStyle(fontSize: 9, color: moss),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 12, 5, 0),
              child: Text(
                product.category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  color: muted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                product.variantName ?? 'Xem quy cách',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.comparePrice > product.price)
                      Text(
                        money(product.comparePrice),
                        style: const TextStyle(
                          fontSize: 9,
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      money(product.price),
                      style: const TextStyle(
                        fontSize: 15,
                        color: moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: sage,
                  child: Icon(Icons.arrow_forward, color: moss, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    ),
  );
}
