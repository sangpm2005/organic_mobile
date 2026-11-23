import 'package:flutter/material.dart';

import '../../../../shared/state/store_scope.dart';
import 'product_quick_actions.dart';
import '../../data/product_stock_cache.dart';
import '../../domain/sale_selection.dart';
import '../../../../core/utils/json.dart';

import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

/// Share text space across a grid while retaining complete product names.
class ProductTileLayout {
  static const categoryStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 8,
    height: 1.4,
    letterSpacing: 1,
    color: muted,
  );
  static const nameStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );
  static const variantStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 10,
    height: 1.4,
    color: muted,
  );
  final double categoryHeight, nameHeight, variantHeight;
  const ProductTileLayout(
    this.categoryHeight,
    this.nameHeight,
    this.variantHeight,
  );

  factory ProductTileLayout.measure(
    BuildContext context,
    List<Product> products,
    double cardWidth,
  ) {
    double tallest(String Function(Product) text, TextStyle style) {
      double height = 0;
      for (final product in products) {
        final painter = TextPainter(
          text: TextSpan(text: text(product), style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: (cardWidth - 26).clamp(1, double.infinity));
        if (painter.height > height) height = painter.height;
        painter.dispose();
      }
      return height.ceilToDouble();
    }

    return ProductTileLayout(
      tallest((p) => p.category.toUpperCase(), categoryStyle),
      tallest((p) => p.name, nameStyle),
      tallest((p) => p.variantName ?? 'Xem quy cách', variantStyle),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final ProductTileLayout? layout;
  const ProductTile(
    this.product, {
    super.key,
    required this.onTap,
    this.layout,
  });
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    if (scope == null || product.variantId == null) return tile(context);
    return FutureBuilder<Json>(
      future: ProductStockCache.forApi(scope.notifier!.api).get(product.id),
      builder: (context, snapshot) {
        final choices = saleChoices(snapshot.data, product.variantId);
        final option = currentSaleChoice(choices);
        final quantity = supportsSaleChoices(snapshot.data)
            ? (option?['availableQuantity'] ??
                  choices.fold<double>(
                    0,
                    (sum, o) => sum + number(o['availableQuantity']),
                  ))
            : object(snapshot.data?['availableQuantity'])[product.variantId];
        if (snapshot.hasData && quantity != null && number(quantity) <= 0) {
          return const SizedBox.shrink();
        }
        return tile(
          context,
          price: option == null ? null : number(option['price']),
          comparePrice: option == null ? null : number(option['regularPrice']),
        );
      },
    );
  }

  Widget tile(BuildContext context, {double? price, double? comparePrice}) =>
      Material(
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
                  child: SizedBox(
                    height: layout?.categoryHeight,
                    child: Text(
                      product.category.toUpperCase(),
                      style: ProductTileLayout.categoryStyle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: SizedBox(
                    height: layout?.nameHeight,
                    child: Text(
                      product.name,
                      style: ProductTileLayout.nameStyle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    height: layout?.variantHeight,
                    child: Text(
                      product.variantName ?? 'Xem quy cách',
                      style: ProductTileLayout.variantStyle,
                    ),
                  ),
                ),
                if (layout != null) const Spacer(),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Visibility(
                            visible:
                                (comparePrice ?? product.comparePrice) >
                                (price ?? product.price),
                            maintainSize: true,
                            maintainState: true,
                            maintainAnimation: true,
                            child: Text(
                              money(comparePrice ?? product.comparePrice),
                              style: const TextStyle(
                                fontSize: 9,
                                color: muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          Text(
                            money(price ?? product.price),
                            style: const TextStyle(
                              fontSize: 15,
                              color: moss,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 15,
                      backgroundColor: sage,
                      child: Icon(Icons.arrow_forward, color: moss, size: 17),
                    ),
                  ],
                ),
                if (context.dependOnInheritedWidgetOfExactType<StoreScope>() !=
                    null)
                  ProductQuickActions(product, choose: onTap),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
}
