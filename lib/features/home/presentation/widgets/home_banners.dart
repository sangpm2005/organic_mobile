import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../../catalog/presentation/catalog_screen.dart';
import '../../../promotions/presentation/promotions_screen.dart';
import '../../../promotions/presentation/widgets/promotion_products.dart';
import '../../../rewards/presentation/widgets/voucher_card.dart';
import '../../../store_info/presentation/store_info_screen.dart';
import '../../../store_info/presentation/contact_screen.dart';

class HomeBanners extends StatelessWidget {
  final List<Json> banners, offers;
  const HomeBanners({super.key, required this.banners, required this.offers});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final banner in banners)
        _Banner(
          title: '${banner['title'] ?? ''}',
          subtitle: '${banner['subtitle'] ?? ''}',
          image: '${banner['imageUrl'] ?? ''}',
          label: '${banner['buttonLabel'] ?? 'Xem chi tiết'}',
          onTap: () {
            final path = Uri.tryParse('${banner['buttonHref']}')?.path;
            final page = switch (path) {
              '/products' || '/san-pham' => const CatalogScreen(),
              '/promotions' || '/khuyen-mai' => const PromotionsScreen(),
              '/contact' || '/lien-he' => const ContactScreen(),
              '/about' ||
              '/about-store' ||
              '/traceability' ||
              '/ve-cua-hang' => const StoreInfoScreen(),
              _ => null,
            };
            if (page != null) {
              open(context, page);
            } else {
              // Unknown web routes are presented as information, never opened as
              // arbitrary links or silently sent to an unrelated destination.
              open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Chương trình từ cửa hàng')),
                  body: ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      Text(
                        '${banner['title'] ?? ''}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text('${banner['subtitle'] ?? ''}'),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      for (final offer in offers.take(3))
        _Banner(
          title: '${offer['name']}',
          subtitle: [
            offer['discountType'] == 'percentage'
                ? 'Giảm ${offer['discountValue']}%'
                : 'Giảm ${money(offer['discountValue'])}',
            if (number(offer['minOrderValue']) > 0)
              'Đơn từ ${money(offer['minOrderValue'])}',
            if ('${offer['description'] ?? ''}'.isNotEmpty)
              '${offer['description']}',
            if (offer['endsAt'] != null) 'Đến ${dateText(offer['endsAt'])}',
          ].join('\n'),
          label: offer['promotionType'] == 'combo'
              ? 'Xem combo ưu đãi'
              : 'Xem chương trình',
          onTap: () => open(
            context,
            Scaffold(
              appBar: AppBar(title: const Text('Chi tiết ưu đãi')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  VoucherCard(offer, action: PromotionProducts(offer: offer)),
                ],
              ),
            ),
          ),
        ),
      if (offers.isNotEmpty)
        TextButton.icon(
          onPressed: () => open(context, const PromotionsScreen()),
          icon: const Icon(Icons.local_offer_outlined),
          label: Text('Xem tất cả ${offers.length} ưu đãi & combo'),
        ),
    ],
  );
}

class _Banner extends StatelessWidget {
  final String title, subtitle, label, image;
  final VoidCallback onTap;
  const _Banner({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
    this.image = '',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
    child: Card(
      color: sage,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (Uri.tryParse(image)?.scheme == 'https')
              Image.network(
                image,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_offer_outlined, color: moss),
                  const SizedBox(height: 10),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(subtitle),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: moss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
