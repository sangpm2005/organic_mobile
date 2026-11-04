import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'auth.dart';
import 'customer.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback catalog;
  const HomeScreen({super.key, required this.catalog});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AsyncView<bool>(
      load: () async {
        await store.loadHome();
        return true;
      },
      builder: (_) => RefreshIndicator(
        onRefresh: store.loadHome,
        child: ListView(
          children: [
            Container(
              color: ink,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
              child: const Text(
                'MỘT CHÚT XANH, MỘT ĐỜI LÀNH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: surface,
                  fontSize: 9,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
              child: Row(
                children: [
                  const Brand(),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Tìm sản phẩm',
                    onPressed: widget.catalog,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () => open(context, const UpdatesScreen()),
                    icon: Badge(
                      isLabelVisible: store.unread > 0,
                      label: Text('${store.unread}'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const Text(
                    'TỪ NÔNG TRẠI ĐẾN BÀN ĂN',
                    style: TextStyle(
                      color: moss,
                      letterSpacing: 1.9,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Lành từ đất.\nTốt cho bạn.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Những lựa chọn tươi lành mỗi ngày.\nKhám phá thực phẩm và câu chuyện nguồn gốc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.8, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: widget.catalog,
                    label: const Text('Khám phá sản phẩm'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                  const SizedBox(height: 26),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/hero.jpg',
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _Trust(Icons.grass, 'Nguồn gốc rõ ràng')),
                      Expanded(
                        child: _Trust(
                          Icons.verified_outlined,
                          'Hồ sơ chứng nhận',
                        ),
                      ),
                      Expanded(
                        child: _Trust(
                          Icons.local_shipping_outlined,
                          'Theo dõi đơn hàng',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Heading(
              'Tươi lành mỗi ngày',
              eyebrow: 'Ghé vườn nhà Mộc',
              trailing: TextButton(
                onPressed: widget.catalog,
                child: const Text('Xem hết →', style: TextStyle(fontSize: 11)),
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                separatorBuilder: (_, i) => const SizedBox(width: 12),
                itemCount: objects(store.home['categories']).length,
                itemBuilder: (_, index) {
                  final c = objects(store.home['categories'])[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => open(
                      context,
                      CatalogScreen(
                        categoryId: '${c['id']}',
                        title: '${c['name']}',
                      ),
                    ),
                    child: Container(
                      width: 125,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: index.isEven ? sage : const Color(0xFFF4E8DC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            [
                              Icons.eco_outlined,
                              Icons.spa_outlined,
                              Icons.grain,
                              Icons.local_florist_outlined,
                            ][index % 4],
                            color: moss,
                            size: 24,
                          ),
                          const Spacer(),
                          Text(
                            '${c['name']}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${c['productCount']} sản phẩm',
                            style: const TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Heading('Mộc chọn cho bạn', eyebrow: 'Sản phẩm nổi bật'),
            ProductGrid(
              store.featured,
              onTap: (p) => open(context, ProductScreen(p.id)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Panel(
                color: sage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.loyalty_outlined, color: moss, size: 30),
                    const SizedBox(height: 12),
                    Text(
                      'Mua lành, tích thêm xanh.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Theo dõi điểm tích lũy và dùng điểm cho những lần mua tiếp theo.',
                      style: TextStyle(color: muted),
                    ),
                    TextButton(
                      onPressed: () => open(context, const RewardsScreen()),
                      child: const Text('Khám phá Mộc thành viên →'),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Text(
                'mộc.  ·  Một chút xanh, một đời lành.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontFamily: 'Lora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Trust(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: moss, size: 21),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(fontSize: 8, color: muted)),
    ],
  );
}

class CatalogScreen extends StatefulWidget {
  final String? categoryId, title;
  final bool embedded;
  const CatalogScreen({
    super.key,
    this.categoryId,
    this.title,
    this.embedded = false,
  });
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  Timer? debounce;
  List<Product> products = [];
  String? category, error;
  int page = 0, requestVersion = 0;
  bool busy = true, hasMore = false;
  String sort = 'newest';
  OrganicStore? store;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (store == null) {
      store = StoreScope.of(context);
      category = widget.categoryId;
      unawaited(store!.loadCategories().catchError((Object _) {}));
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    final version = ++requestVersion;
    final requestedPage = more ? page + 1 : 0;
    setState(() {
      busy = true;
      error = null;
      if (!more) {
        page = 0;
      }
    });
    try {
      final result = await store!.products(
        keyword: search.text.trim(),
        categoryId: category,
        page: requestedPage,
        sortBy: sort == 'newest' ? 'createdAt' : 'productName',
        direction: sort == 'low' ? 'asc' : 'desc',
      );
      if (!mounted || version != requestVersion) {
        return;
      }
      setState(() {
        products = more ? [...products, ...result] : result;
        page = requestedPage;
        hasMore = result.length == 20;
      });
    } catch (e) {
      if (mounted && version == requestVersion) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && version == requestVersion) {
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    search.dispose();
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: load,
      child: ListView(
        children: [
          Heading(widget.title ?? 'Ghé vườn nhà Mộc', eyebrow: 'Sản phẩm'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TextField(
              key: const ValueKey('catalog.search'),
              controller: search,
              decoration: const InputDecoration(
                hintText: 'Hôm nay bạn tìm gì?',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 350), load);
              },
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: category == null,
                    onSelected: (_) {
                      category = null;
                      load();
                    },
                  ),
                ),
                ...(store?.categories ?? <Json>[]).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${c['name']}'),
                      selected: category == c['id'],
                      onSelected: (_) {
                        category = '${c['id']}';
                        load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${products.length} sản phẩm đã tải',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                DropdownButton<String>(
                  value: sort,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    color: ink,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
                    DropdownMenuItem(value: 'low', child: Text('Tên A–Z')),
                    DropdownMenuItem(value: 'high', child: Text('Tên Z–A')),
                  ],
                  onChanged: (v) {
                    sort = v!;
                    load();
                  },
                ),
              ],
            ),
          ),
          if (error != null)
            EmptyState(
              'Chưa tải được sản phẩm',
              error!,
              action: OutlinedButton(
                onPressed: load,
                child: const Text('Thử lại'),
              ),
            )
          else if (!busy && products.isEmpty)
            const EmptyState(
              'Chưa tìm thấy sản phẩm',
              'Thử một từ khóa hoặc danh mục khác.',
            )
          else
            ProductGrid(
              products,
              onTap: (p) => open(context, ProductScreen(p.id)),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (!busy && hasMore)
            Padding(
              padding: const EdgeInsets.all(22),
              child: OutlinedButton(
                onPressed: () => load(more: true),
                child: const Text('Xem thêm sản phẩm'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Brand()),
            body: content,
          );
  }
}

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
    appBar: AppBar(title: const Text('Từ vườn nhà Mộc')),
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
            AsyncView<Json>(
              load: () async => object(
                await StoreScope.of(context).api.request(
                  'GET',
                  '/products/${widget.id}/reviews',
                  authenticated: false,
                ),
              ),
              builder: (reviews) => Column(
                children: pageItems(reviews['reviews'])
                    .map(
                      (r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${r['title'] ?? r['customerName'] ?? 'Khách hàng'} · ${r['rating']} ★',
                        ),
                        subtitle: Text('${r['content'] ?? ''}'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    ),
  );
}
