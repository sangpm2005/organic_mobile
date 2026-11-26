import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../../../shared/widgets/offer_carousel.dart';
import '../../../../shared/widgets/panel.dart';
import '../../../catalog/presentation/widgets/product_photo.dart';
import '../../../rewards/presentation/widgets/voucher_card.dart';
import '../../domain/combo_pricing.dart';
import 'promotion_products.dart';

Future<void> openPromotion(BuildContext context, Json offer) async {
  await open(
    context,
    Scaffold(
      appBar: AppBar(title: const Text('Chi tiết ưu đãi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [VoucherCard(offer, action: PromotionProducts(offer: offer))],
      ),
    ),
  );
}

class PromotionCarousel extends StatelessWidget {
  final List<Json> offers;
  const PromotionCarousel({super.key, required this.offers});

  @override
  Widget build(BuildContext context) => OfferCarousel(
    slideIds: offers.map((o) => '${o['id']}').toList(),
    onOpen: (index) => openPromotion(context, offers[index]),
    slides: [for (final offer in offers) _PromotionPreview(offer)],
  );
}

class _PromotionPreview extends StatelessWidget {
  final Json offer;
  const _PromotionPreview(this.offer);

  @override
  Widget build(BuildContext context) {
    final products = objects(offer['products']);
    final estimate = offer['promotionType'] == 'combo'
        ? comboEstimate(offer, initialComboVariant)
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Panel(
        color: sage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OfferCarouselTapArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer['promotionType'] == 'combo'
                        ? 'COMBO ƯU ĐÃI'
                        : 'ƯU ĐÃI TỪ CỬA HÀNG',
                    style: const TextStyle(
                      color: moss,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${offer['name'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer['discountType'] == 'percentage'
                        ? 'Giảm ${offer['discountValue']}%'
                        : 'Giảm ${money(offer['discountValue'])}${offer['promotionType'] == 'combo' ? ' mỗi bộ' : ''}',
                  ),
                  if ('${offer['description'] ?? ''}'.isNotEmpty)
                    Text('${offer['description']}'),
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    // A wrap keeps vertical scrolling and the carousel swipe independent.
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (final product in products)
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ProductPhoto(
                                      '${product['imageUrl'] ?? ''}',
                                      height: 100,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${product['productName'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (initialComboVariant(product)?['price'] !=
                                      null)
                                    Text(
                                      '${offer['promotionType'] == 'combo' ? '${number(product['requiredQuantity']).toInt()} × ' : ''}${money(initialComboVariant(product)!['price'])}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (estimate != null) ...[
                    const Divider(height: 26),
                    const Text(
                      'Giá combo tạm tính',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      money(estimate.total),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (estimate.discount > 0)
                      Text(
                        'Tiết kiệm ${money(estimate.discount)} · Giá gốc ${money(estimate.subtotal)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                  if (number(offer['minOrderValue']) > 0)
                    Text(
                      'Đơn từ ${money(offer['minOrderValue'])}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (offer['maxDiscountAmount'] != null)
                    Text(
                      'Giảm tối đa ${money(offer['maxDiscountAmount'])}/đơn',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (offer['endsAt'] != null)
                    Text(
                      'Kết thúc: ${dateText(offer['endsAt'])}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => openPromotion(context, offer),
              child: Text(
                offer['promotionType'] == 'combo'
                    ? 'Xem combo & chọn quy cách →'
                    : 'Xem chi tiết ưu đãi →',
              ),
            ),
            const Text(
              'Chạm để chuyển · Chạm hai lần để xem chi tiết',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
