import 'package:flutter/material.dart';

import '../../../shared/widgets/visible_refresh.dart';
import 'widgets/product_suggestions.dart';
import 'widgets/product_description.dart';
import '../../../shared/widgets/certificate_preview.dart';

import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/catalog/domain/product_detail.dart';

import '../../catalog/domain/sale_selection.dart';
import 'widgets/sale_option_picker.dart';

import 'package:organic_mobile/features/catalog/presentation/widgets/product_gallery.dart';
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
  final Json? initialSale;
  const ProductScreen(this.id, {super.key, this.initialSale});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final view = GlobalKey<AsyncViewState<Json>>();
  Json? selected;
  Json? availability;
  bool availabilityFailed = false;
  bool initializedSale = false;
  int quantity = 1;
  int reviewRevision = 0;
  bool adding = false;
  Future<Json> load() async {
    final store = StoreScope.of(context);
    final api = store.api;
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
      availabilityFailed = false;
    } catch (_) {
      availability = null;
      availabilityFailed = true;
    }
    final covers = objects(store.home['certifications']);
    detail['certifications'] = objects(detail['certifications'])
        .map((certificate) {
          final cover = covers
              .where(
                (c) =>
                    c['id'] == certificate['id'] &&
                    c['number'] == certificate['certificateNumber'],
              )
              .firstOrNull;
          return {
            ...certificate,
            if (cover?['previewImageUrl'] != null)
              'previewImageUrl': cover!['previewImageUrl'],
          };
        })
        .toList();
    final variants = sellableVariants(detail);
    selected =
        variants.where((v) => v['id'] == selected?['id']).firstOrNull ??
        (!initializedSale
            ? variants
                  .where((v) => v['id'] == widget.initialSale?['variantId'])
                  .firstOrNull
            : null) ??
        variants
            .where((v) => v['id'] == detail['defaultVariantId'])
            .firstOrNull ??
        variants.firstOrNull;
    initializedSale = true;
    final stock =
        currentSale?['availableQuantity'] ??
        object(availability?['availableQuantity'])[selected?['id']];
    if (stock != null && number(stock) > 0) {
      quantity = quantity.clamp(1, number(stock).toInt().clamp(1, 999));
    }
    return detail;
  }

  Json? get currentSale =>
      currentSaleChoice(saleChoices(availability, selected?['id']?.toString()));

  Future<void> add() async {
    if (adding ||
        selected == null ||
        !mounted ||
        availabilityFailed ||
        (supportsSaleChoices(availability) && currentSale == null)) {
      return;
    }
    setState(() => adding = true);
    try {
      await StoreScope.of(context)
          .add('${selected!['id']}', quantity, sale: currentSale);
      if (mounted) {
        toast(context, 'Đã thêm vào giỏ hàng của bạn.');
      }
    } catch (e) {
      if (mounted) {
        toast(context, e);
        if (e is ApiException && e.status == 409) {
          await view.currentState?.refresh();
        }
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
    body: VisibleRefresh(
      refresh: () async {
        if (!adding) await view.currentState?.refresh();
      },
      child: AsyncView<Json>(
        key: view,
        load: load,
        builder: (data) {
          final variants = sellableVariants(data);
          final images = productImages(
            data,
            baseUrl: StoreScope.of(context).api.baseUrl,
          );
          final supports = supportsSaleChoices(availability);
          final choices = saleChoices(
            availability,
            selected?['id']?.toString(),
          );
          final sale = currentSale;
          final stock = supports
              ? (sale?['availableQuantity'] ?? 0)
              : (object(availability?['availableQuantity'])[selected?['id']]);
          final price = sale?['price'] ?? selected?['sellingPrice'];
          final compare = sale?['regularPrice'] ?? selected?['compareAtPrice'];
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            children: [
              ProductGallery(
                images,
                key: ValueKey('product.gallery.${widget.id}'),
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
              if (selected != null && number(compare) > number(price))
                Text(
                  money(compare),
                  style: const TextStyle(
                    color: muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                selected == null
                    ? 'Hiện chưa có quy cách đang bán'
                    : money(price),
                key: const ValueKey('product.price'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: moss,
                ),
              ),
              const SizedBox(height: 16),
              if (variants.isNotEmpty) ...[
                const Text(
                  'Chọn khối lượng / dung tích',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: variants
                    .map(
                      (v) => ChoiceChip(
                        key: ValueKey('product.variant.${v['id']}'),
                        label: Text(variantDisplayName(v)),
                        selected: selected?['id'] == v['id'],
                        onSelected: adding
                            ? null
                            : (_) => setState(() {
                                selected = v;
                                quantity = 1;
                              }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 15),
              if (supports) ...[
                SaleOfferNotice(
                  selected: sale,
                  comboOnly: choices.any((o) => o['combo'] == true),
                ),
                const SizedBox(height: 10),
              ],
              if (availabilityFailed) ...[
                const Text(
                  'Chưa kiểm tra được hạn sử dụng và tồn kho. Vui lòng tải lại trước khi thêm hàng.',
                ),
                TextButton(
                  onPressed: adding ? null : () => view.currentState?.refresh(),
                  child: const Text('Kiểm tra lại hàng hiện có'),
                ),
              ],
              Text(
                stock == null
                    ? 'Tồn kho được kiểm tra khi thêm vào giỏ và đặt hàng.'
                    : 'Có thể mua: $stock sản phẩm theo quy cách đã chọn',
                key: const ValueKey('product.stock'),
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('product.decrease'),
                        onPressed: !adding && quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$quantity'),
                      IconButton(
                        key: const ValueKey('product.increase'),
                        onPressed:
                            !adding &&
                                quantity < 999 &&
                                !availabilityFailed &&
                                (stock == null || quantity < number(stock))
                            ? () => setState(() => quantity++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('product.add'),
                      onPressed:
                          adding ||
                              selected == null ||
                              availabilityFailed ||
                              (supports && sale == null) ||
                              (stock != null && number(stock) <= 0) ||
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
              ProductDescription('${data['description'] ?? ''}'),
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
                  (c) => Column(
                    children: [
                      CertificatePreview(c),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.verified_outlined,
                          color: moss,
                        ),
                        title: Text('${c['certificateName']}'),
                        subtitle: Text(
                          '${c['issuingOrganization']}\nHết hạn: ${c['expiresAt'] ?? 'Chưa cung cấp'}',
                        ),
                        trailing: c['documentUrl'] != null
                            ? IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                onPressed: () async {
                                  final uri = Uri.tryParse(
                                    '${c['documentUrl']}',
                                  );
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
                    ],
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
              const SizedBox(height: 20),
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
              ProductSuggestions(
                productId: widget.id,
                related: objects(data['relatedProducts']),
              ),
            ],
          );
        },
      ),
    ),
  );
}
