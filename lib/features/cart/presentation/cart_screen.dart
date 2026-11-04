import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/account_error.dart';
import 'package:organic_mobile/shared/widgets/amount_row.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool busy = false;
  Future<void> change(Json item, int quantity) async {
    setState(() => busy = true);
    try {
      await StoreScope.of(context).quantity('${item['variantId']}', quantity);
    } catch (e) {
      if (mounted) {
        toast(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loggedIn) {
      return const LoginGate(
        'Đăng nhập để đồng bộ giỏ hàng của bạn giữa ứng dụng và website.',
      );
    }
    if (store.cart == null && store.accountError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: store.refreshAccount,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Heading('Giỏ xanh của bạn', eyebrow: 'organicfood đồng hành'),
          if (store.accountError != null) AccountError(store),
          if (store.cartItems.isEmpty)
            const EmptyState(
              'Giỏ hàng còn đang trống',
              'Ghé vườn nhà organicfood và chọn một chút tươi lành cho hôm nay.',
              icon: Icons.shopping_bag_outlined,
            ),
          ...store.cartItems.map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Panel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 75,
                          height: 85,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ProductPhoto('${item['imageUrl'] ?? ''}'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['productName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['variantName']}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                money(item['unitPrice']),
                                style: const TextStyle(
                                  color: moss,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bỏ sản phẩm khỏi giỏ',
                          onPressed: busy ? null : () => change(item, 0),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    if (item['available'] != true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${item['unavailableMessage'] ?? 'Sản phẩm chưa đủ điều kiện đặt mua.'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Giảm số lượng',
                          onPressed: busy
                              ? null
                              : () => change(
                                  item,
                                  (item['quantity'] as num).toInt() - 1,
                                ),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 22,
                          ),
                        ),
                        Text('${item['quantity']}'),
                        IconButton(
                          tooltip: 'Tăng số lượng',
                          onPressed: busy || number(item['quantity']) >= 999
                              ? null
                              : () => change(
                                  item,
                                  (item['quantity'] as num).toInt() + 1,
                                ),
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          money(item['lineTotal']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (store.cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panel(
                    color: sage,
                    child: Column(
                      children: [
                        AmountRow(
                          'Tạm tính',
                          store.cart?['subtotal'],
                          total: true,
                        ),
                        const Text(
                          'Áp dụng ưu đãi và điểm tích lũy ở bước tiếp theo.',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            store.cartItems.any((i) => i['available'] != true)
                        ? null
                        : () => open(
                            context,
                            const CheckoutScreen(),
                            account: true,
                          ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Tiến hành đặt hàng'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
