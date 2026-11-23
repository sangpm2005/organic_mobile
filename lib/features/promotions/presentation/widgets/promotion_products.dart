import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../catalog/presentation/product_screen.dart';
import '../../../catalog/domain/sale_selection.dart';
import '../../../catalog/domain/product_detail.dart';
import '../../../catalog/presentation/widgets/sale_option_picker.dart';
import '../../../../core/network/api_exception.dart';

class PromotionProducts extends StatefulWidget {
  final Json offer;
  const PromotionProducts({super.key, required this.offer});
  @override
  State<PromotionProducts> createState() => _PromotionProductsState();
}

class _PromotionProductsState extends State<PromotionProducts> {
  final Map<String, String> selected = {};
  bool busy = false;
  bool stale = false;
  String choiceKey(Json v) => saleKey({...v, 'variantId': v['id']});
  Json? choice(Json p) =>
      objects(p['variants'])
          .where((v) => choiceKey(v) == selected['${p['productId']}'])
          .firstOrNull;
  bool enough(Json p) {
    final v = choice(p);
    if (v == null) return false;
    final current = StoreScope.of(context).cartItems
        .where((row) => saleKey(row) == choiceKey(v))
        .fold<double>(0, (sum, row) => sum + number(row['quantity']));
    return current + quantity(p) <= number(v['availableQuantity']) &&
        current + quantity(p) <= 999;
  }

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
      if (v != null) selected['${p['productId']}'] = choiceKey(v);
    }
  }

  Future<void> add() async {
    final store = StoreScope.of(context);
    if (busy || stale) return;
    setState(() => busy = true);
    try {
      if (products.any((p) => !enough(p))) {
        throw const ApiException(
          'Chưa đủ hàng ở lựa chọn này. Hãy điều chỉnh giỏ hoặc chọn lại quy cách / hạn sử dụng.',
        );
      }
      await store.addBatch(
        products
            .map(
              (p) => {
                'variantId': choice(p)!['id'],
                'quantity': quantity(p),
                ...saleFields(choice(p)),
              },
            )
            .toList(),
      );
      if (widget.offer['saleScope'] != 'expiry') {
        store.selectPromotion('${widget.offer['promotionCode']}');
      }
      if (mounted) {
        toast(
          context,
          'Đã thêm combo vào giỏ. Giá ưu đãi được kiểm tra khi đặt hàng.',
        );
      }
    } catch (e) {
      if (mounted) {
        toast(context, e);
        if (e is ApiException && e.status == 409) setState(() => stale = true);
      }
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
              key: ValueKey(
                'combo.choice.${p['productId']}.${selected['${p['productId']}']}',
              ),
              initialValue:
                  available(p)
                      .any((v) => choiceKey(v) == selected['${p['productId']}'])
                  ? selected['${p['productId']}']
                  : null,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              items: available(p)
                  .map(
                    (v) => DropdownMenuItem(
                      value: choiceKey(v),
                      child: Text(
                        '${variantDisplayName(v)} · ${money(v['price'])}${v['expiryDate'] == null ? '' : '\nHSD: ${saleDate(v['expiryDate'])}'}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() => selected['${p['productId']}'] = v!),
            ),
          if (combo && choice(p) != null) SaleExpiry(choice(p)!['expiryDate']),
          if (combo && available(p).isEmpty)
            const Text('Chưa đủ hàng cho sản phẩm này.'),
        ],
        if (combo)
          FilledButton(
            onPressed:
                busy ||
                    stale ||
                    products.isEmpty ||
                    products.any((p) => !enough(p))
                ? null
                : add,
            child: Text(busy ? 'Đang thêm…' : 'Thêm combo vào giỏ'),
          ),
        if (stale)
          const Text(
            'Ưu đãi hoặc tồn kho đã thay đổi. Vui lòng mở lại trang ưu đãi để tải dữ liệu mới.',
          ),
      ],
    );
  }
}
