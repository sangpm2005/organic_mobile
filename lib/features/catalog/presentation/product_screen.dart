import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/async_view.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../reviews/presentation/reviews_screen.dart';
import '../../reviews/presentation/widgets/product_reviews.dart';

class ProductScreen extends StatefulWidget {
  final String id;
  const ProductScreen(this.id, {super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Json? selected;
  Json? availability;
  int quantity = 1;
  int reviewRevision = 0;
  bool adding = false;
  Future<Json> load() async {
    final api = StoreScope.of(context).api;
    final detail = object(
      await api.request('GET', '/products/${widget.id}', authenticated: false),
    );
    try {
      availability = object(
        await api.request(
          'GET',
          '/products/${widget.id}/availability',
          authenticated: false,
        ),
      );
    } catch (_) {
      availability = null;
    }
    final variants = objects(detail['variants']);
    selected ??=
        variants
            .where((v) => v['id'] == detail['defaultVariantId'])
            .firstOrNull ??
        variants.firstOrNull;
    return detail;
  }

  Future<void> add() async {
    if (!await ensureLogin(context) || selected == null || !mounted) {
      return;
    }
    setState(() => adding = true);
    try {
      await StoreScope.of(context).add('${selected!['id']}', quantity);
      if (mounted) {
        toast(context, 'Đã thêm vào giỏ hàng của bạn.');
      }
    } catch (e) {
      if (mounted) {
        toast(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sản phẩm organicfood'),
      actions: [
        IconButton(
          tooltip: 'Lưu sản phẩm yêu thích',
          icon: Icon(
            StoreScope.of(context).favorites.contains(widget.id)
                ? Icons.favorite
                : Icons.favorite_border,
          ),
          onPressed: () async {
            try {
              await StoreScope.of(context).toggleFavorite(widget.id);
            } catch (e) {
              if (context.mounted) toast(context, e);
            }
          },
        ),
      ],
    ),
    body: AsyncView<Json>(
      load: load,
      builder: (data) {
        final variants = objects(data['variants']);
        final image = objects(data['images']).firstOrNull?['imageUrl'] ?? '';
        final stock = object(
          availability?['availableQuantity'],
        )[selected?['id']];
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ProductPhoto('$image', height: 300),
            ),
            const SizedBox(height: 22),
            Text(
              '${data['categoryName']}'.toUpperCase(),
              style: const TextStyle(
                letterSpacing: 1.5,
                fontSize: 10,
                color: moss,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['productName']}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (data['organicVerified'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '✓ Có chứng nhận hữu cơ còn hiệu lực',
                  style: TextStyle(color: moss, fontSize: 11),
                ),
              ),
            const SizedBox(height: 15),
            Text(
              money(selected?['sellingPrice'] ?? data['minPrice']),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: moss,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variants
                  .map(
                    (v) => ChoiceChip(
                      key: ValueKey('product.variant.${v['id']}'),
                      label: Text('${v['variantName']}'),
                      selected: selected?['id'] == v['id'],
                      onSelected: (_) => setState(() {
                        selected = v;
                        quantity = 1;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 15),
            Text(
              stock == null
                  ? 'Tồn kho được kiểm tra khi thêm vào giỏ và đặt hàng.'
                  : 'Có thể mua: $stock gói',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            Row(
              children: [
                IconButton(
                  key: const ValueKey('product.decrease'),
                  onPressed: quantity > 1
                      ? () => setState(() => quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$quantity'),
                IconButton(
                  key: const ValueKey('product.increase'),
                  onPressed:
                      quantity < 999 &&
                          (stock == null || quantity < number(stock))
                      ? () => setState(() => quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('product.add'),
                    onPressed:
                        adding ||
                            selected == null ||
                            stock == 0 ||
                            data['canAddToCart'] == false
                        ? null
                        : add,
                    icon: Icon(
                      adding
                          ? Icons.hourglass_empty
                          : Icons.shopping_bag_outlined,
                      size: 18,
                    ),
                    label: const Text('Thêm vào giỏ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Divider(),
            const SizedBox(height: 14),
            Text(
              'Câu chuyện sản phẩm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('${data['description'] ?? 'Chưa có mô tả.'}'),
            if (data['origin'] != null) ...[
              const SizedBox(height: 22),
              Panel(
                color: sage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, color: moss),
                    const SizedBox(height: 8),
                    Text(
                      '${object(data['origin'])['originName']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        object(data['origin'])['region'],
                        object(data['origin'])['country'],
                      ].where((e) => e != null).join(', '),
                    ),
                    if (object(data['origin'])['producerName'] != null)
                      Text('${object(data['origin'])['producerName']}'),
                  ],
                ),
              ),
            ],
            if (objects(data['certifications']).isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Hồ sơ chứng nhận',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ...objects(data['certifications']).map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_outlined, color: moss),
                  title: Text('${c['certificateName']}'),
                  subtitle: Text(
                    '${c['issuingOrganization']}\nHết hạn: ${c['expiresAt'] ?? 'Chưa cung cấp'}',
                  ),
                  trailing: c['documentUrl'] != null
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () async {
                            final uri = Uri.tryParse('${c['documentUrl']}');
                            if (uri != null &&
                                ['http', 'https'].contains(uri.scheme)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        )
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Đánh giá từ khách hàng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '${object(data['reviewSummary'])['totalReviews'] ?? 0} đánh giá · ${object(data['reviewSummary'])['averageRating'] ?? 'Chưa có điểm'} / 5',
              style: const TextStyle(color: muted),
            ),
            ProductReviews(widget.id, revision: reviewRevision),
            TextButton.icon(
              onPressed: () async {
                if (await ensureLogin(context) && context.mounted) {
                  await open(
                    context,
                    ReviewsScreen(productId: widget.id),
                    account: true,
                  );
                  if (mounted) setState(() => reviewRevision++);
                }
              },
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Viết / quản lý đánh giá sản phẩm'),
            ),
          ],
        );
      },
    ),
  );
}
