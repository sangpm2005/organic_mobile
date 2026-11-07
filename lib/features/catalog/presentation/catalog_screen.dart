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
  final scroll = ScrollController();
  Timer? debounce;
  List<Product> products = [];
  String? category, error;
  int page = 0, requestVersion = 0, total = 0, pages = 0;
  bool busy = true;
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

  Future<void> load({int targetPage = 0}) async {
    final version = ++requestVersion;
    final requestedPage = targetPage;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await store!.productPage(
        keyword: search.text.trim(),
        categoryId: category,
        page: requestedPage,
        size: 8,
        sortBy: sort == 'newest' ? 'createdAt' : 'productName',
        direction: sort == 'low' ? 'asc' : 'desc',
      );
      if (!mounted || version != requestVersion) {
        return;
      }
      setState(() {
        products = result.items.take(8).toList();
        page = requestedPage;
        total = result.total;
        pages = result.pages;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
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
    scroll.dispose();
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: load,
      child: ListView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
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
                    '$total sản phẩm · Tối đa 8 sản phẩm / trang',
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
          else if (!busy)
            ProductGrid(
              products,
              onTap: (p) => open(context, ProductScreen(p.id)),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (pages > 1)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('catalog.previous'),
                    onPressed: busy || page == 0
                        ? null
                        : () => load(targetPage: page - 1),
                    child: const Text('Trang trước'),
                  ),
                  Text('Trang ${page + 1} / $pages'),
                  OutlinedButton(
                    key: const ValueKey('catalog.next'),
                    onPressed: busy || page + 1 >= pages
                        ? null
                        : () => load(targetPage: page + 1),
                    child: const Text('Trang sau'),
                  ),
                ],
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
