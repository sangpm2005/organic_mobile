import 'dart:async';

import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/product_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_grid.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/brand.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';

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
          Heading(
            widget.title ?? 'Ghé vườn nhà organicfood',
            eyebrow: 'Sản phẩm',
          ),
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
