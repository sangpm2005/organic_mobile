import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../promotions/presentation/widgets/promotion_products.dart';
import '../../../rewards/presentation/widgets/voucher_card.dart';
import '../../domain/product.dart';
import '../product_screen.dart';
import 'product_grid.dart';

class ProductSuggestions extends StatelessWidget {
  final String productId;
  final List<Json> related;
  const ProductSuggestions({
    super.key,
    required this.productId,
    required this.related,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AsyncView<List<Json>>(
        key: ValueKey('cross-sell.$productId'),
        load: () async {
          try {
            return objects(
                  await StoreScope.of(context).api.request(
                    'GET',
                    '/products/${Uri.encodeComponent(productId)}/cross-sell',
                    query: {'k': 3},
                    authenticated: false,
                  ),
                )
                .where(
                  (p) =>
                      '${p['productId'] ?? ''}'.isNotEmpty &&
                      '${p['productId']}' != productId,
                )
                .take(3)
                .toList();
          } catch (_) {
            return []; // An optional suggestion must not block buying the product.
          }
        },
        builder: (rows) => rows.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý mua kèm',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Những sản phẩm thường được mua cùng trong các đơn đã hoàn tất.',
                    ),
                    for (final row in rows)
                      TextButton.icon(
                        onPressed: () =>
                            open(context, ProductScreen('${row['productId']}')),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text('${row['productName'] ?? 'Xem sản phẩm'}'),
                      ),
                  ],
                ),
              ),
      ),
      if (related.isNotEmpty) ...[
        const SizedBox(height: 28),
        Text(
          'Có thể bạn cũng thích',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ProductGrid(
          related
              .where((p) => '${p['id']}' != productId)
              .take(6)
              .map(Product.fromJson)
              .toList(),
          onTap: (p) => open(context, ProductScreen(p.id, initialSale: p.sale)),
        ),
      ],
      AsyncView<List<Json>>(
        load: () async {
          final offers = await StoreScope.of(context).promotionService.feed();
          return offers
              .where(
                (p) =>
                    p['promotionType'] == 'combo' &&
                    objects(p['products'])
                        .any((r) => '${r['productId']}' == productId),
              )
              .toList();
        },
        builder: (offers) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Mua kèm, thêm tiết kiệm',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
            for (final offer in offers)
              VoucherCard(offer, action: PromotionProducts(offer: offer)),
          ],
        ),
      ),
    ],
  );
}
