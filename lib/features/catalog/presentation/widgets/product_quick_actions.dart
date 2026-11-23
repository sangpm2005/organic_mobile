import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/sale_selection.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../data/product_stock_cache.dart';
import '../../domain/product.dart';

class ProductQuickActions extends StatefulWidget {
  final Product product;
  final VoidCallback choose;
  const ProductQuickActions(this.product, {super.key, required this.choose});
  @override
  State<ProductQuickActions> createState() => _ProductQuickActionsState();
}

class _ProductQuickActionsState extends State<ProductQuickActions> {
  Future<Json>? stock;
  ProductStockCache? cache;
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cache ??= ProductStockCache.forApi(StoreScope.of(context).api);
    stock ??= cache!.get(widget.product.id);
  }

  @override
  void didUpdateWidget(covariant ProductQuickActions old) {
    super.didUpdateWidget(old);
    if (!identical(old.product, widget.product)) {
      stock = cache!.get(widget.product.id);
    }
  }

  Future<void> add() async {
    final p = widget.product;
    if (busy) return;
    if (p.variantId == null) {
      widget.choose();
      return;
    }
    final store = StoreScope.of(context);
    final sessionVersion = store.api.sessionVersion;
    setState(() => busy = true);
    try {
      final available = await stock!;
      if (!mounted) return;
      final previous = currentSaleChoice(saleChoices(available, p.variantId));
      final fresh = await cache!.get(p.id, fresh: true);
      if (!mounted) return;
      final option = currentSaleChoice(saleChoices(fresh, p.variantId));
      if (store.api.sessionVersion != sessionVersion) {
        toast(
          context,
          'Phiên đăng nhập đã thay đổi. Vui lòng chọn lại sản phẩm.',
        );
        return;
      }
      setState(() {
        stock = Future.value(fresh);
      });
      if (supportsSaleChoices(fresh) && option == null) {
        widget.choose();
        return;
      }
      if (previous != null &&
          option != null &&
          (saleKey(previous) != saleKey(option) ||
              number(previous['price']) != number(option['price']))) {
        toast(
          context,
          'Ưu đãi hoặc giá vừa thay đổi. Vui lòng xem lại trước khi thêm hàng.',
        );
        widget.choose();
        return;
      }
      final quantity =
          option?['availableQuantity'] ??
          object(fresh['availableQuantity'])[p.variantId];
      if (quantity == null || number(quantity) <= 0) {
        widget.choose();
        return;
      }
      await store.add(p.variantId!, 1, sale: option);
      cache!.invalidate(p.id);
      if (mounted) {
        setState(() {
          stock = cache!.get(p.id);
        });
        toast(
          context,
          'Đã thêm ${p.name} · ${p.variantName ?? 'quy cách đã chọn'} vào giỏ.',
        );
      }
    } catch (e) {
      if (mounted) {
        toast(context, e);
        if (e is ApiException && e.status == 409) {
          cache!.invalidate(p.id);
          setState(() {
            stock = cache!.get(p.id);
          });
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), p = widget.product;
    return FutureBuilder<Json>(
      future: stock,
      builder: (context, snapshot) {
        final supported = supportsSaleChoices(snapshot.data);
        final choices = saleChoices(snapshot.data, p.variantId);
        final option = currentSaleChoice(choices);
        final count = supported
            ? (option?['availableQuantity'] ??
                  choices.fold<double>(
                    0,
                    (sum, o) => sum + number(o['availableQuantity']),
                  ))
            : (object(snapshot.data?['availableQuantity'])[p.variantId]);
        final needsChoice =
            supported &&
            option == null &&
            choices.any((o) => o['combo'] == true);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == null
                  ? 'Xem số lượng trong chi tiết'
                  : 'Có thể mua: $count',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: store.favorites.contains(p.id)
                      ? 'Bỏ yêu thích'
                      : 'Lưu yêu thích',
                  icon: Icon(
                    store.favorites.contains(p.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  onPressed: () async {
                    try {
                      await store.toggleFavorite(p.id);
                    } catch (e) {
                      if (context.mounted) toast(context, e);
                    }
                  },
                ),
                TextButton.icon(
                  onPressed:
                      busy ||
                          (!needsChoice && count != null && number(count) <= 0)
                      ? null
                      : needsChoice
                      ? widget.choose
                      : add,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(
                    busy
                        ? 'Đang thêm…'
                        : needsChoice
                        ? 'Xem combo'
                        : count != null && number(count) <= 0
                        ? 'Hết hàng'
                        : p.variantId == null
                        ? 'Chọn loại'
                        : 'Thêm',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
