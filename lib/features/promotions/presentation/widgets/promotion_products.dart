import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../catalog/presentation/product_screen.dart';

class PromotionProducts extends StatefulWidget {
  final Json offer;
  const PromotionProducts({super.key, required this.offer});
  @override
  State<PromotionProducts> createState() => _PromotionProductsState();
}

class _PromotionProductsState extends State<PromotionProducts> {
  final Map<String, String> selected = {};
  bool busy = false;
  List<Json> get products => objects(widget.offer['products']);
  int quantity(Json p) => number(p['requiredQuantity']).toInt().clamp(1, 999);
  List<Json> available(Json p) =>
      objects(p['variants'])
          .where((v) => number(v['availableQuantity']) >= quantity(p))
          .toList();
  @override
  void initState() {
    super.initState();
    for (final p in products) {
      final v = available(p).firstOrNull;
      if (v != null) selected['${p['productId']}'] = '${v['id']}';
    }
  }

  Future<void> add() async {
    final store = StoreScope.of(context);
    if (busy) return;
    setState(() => busy = true);
    try {
      await store.addBatch(
        products
            .map(
              (p) => {
                'variantId': selected['${p['productId']}'],
                'quantity': quantity(p),
              },
            )
            .toList(),
      );
      store.selectPromotion('${widget.offer['promotionCode']}');
      if (mounted) {
        toast(
          context,
          'Đã thêm combo vào giỏ. Giá ưu đãi được kiểm tra khi đặt hàng.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.offer['promotionType'] == 'combo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in products) ...[
          TextButton(
            onPressed: () => open(context, ProductScreen('${p['productId']}')),
            child: Text(
              '${p['productName']}${combo ? ' × ${quantity(p)}' : ''}',
            ),
          ),
          if (combo && available(p).isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: selected['${p['productId']}'],
              isExpanded: true,
              items: available(p)
                  .map(
                    (v) => DropdownMenuItem(
                      value: '${v['id']}',
                      child: Text(
                        '${v['variantName']} · ${money(v['price'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() => selected['${p['productId']}'] = v!),
            ),
          if (combo && available(p).isEmpty)
            const Text('Chưa đủ hàng cho sản phẩm này.'),
        ],
        if (combo)
          FilledButton(
            onPressed:
                busy ||
                    products.isEmpty ||
                    products.any((p) => available(p).isEmpty)
                ? null
                : add,
            child: Text(busy ? 'Đang thêm…' : 'Thêm combo vào giỏ'),
          ),
      ],
    );
  }
}
