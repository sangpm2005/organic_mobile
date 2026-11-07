import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/features/catalog/domain/product_detail.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/account_error.dart';

import 'widgets/cart_voucher_summary.dart';

import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

import '../../account/presentation/profile_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool busy = false;
  Future<void> proceed() async {
    if (busy) return;
    final store = StoreScope.of(context);
    setState(() => busy = true);
    try {
      if (!await ensureLogin(context) || !mounted) return;
      await store.refreshCart();
      if (!mounted || !store.loggedIn) return;
      if ('${store.cart?['mergeStatus']}'.startsWith('PENDING_')) {
        toast(
          context,
          'Giỏ khách vẫn được giữ. Giảm số lượng trong giỏ tài khoản rồi thử đồng bộ lại.',
        );
        return;
      }
      if (store.cartItems.isEmpty ||
          store.cartItems.any((i) => i['available'] != true)) {
        toast(
          context,
          'Vui lòng kiểm tra sản phẩm và số lượng trong giỏ trước khi đặt hàng.',
        );
        return;
      }
      if (store.profileCompletionRequired) {
        await open(context, const ProfileScreen(), account: true);
        if (!mounted || !store.loggedIn) return;
        if (store.profileCompletionRequired) {
          toast(context, 'Bổ sung số điện thoại trước khi đặt hàng.');
          return;
        }
      }
      await open(context, const CheckoutScreen(), account: true);
    } catch (error) {
      if (mounted) toast(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
    if (store.loggedIn && store.cart == null && store.accountError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await store.refreshCart();
        } catch (error) {
          if (context.mounted) toast(context, error);
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Heading('Giỏ xanh của bạn', eyebrow: 'organicfood đồng hành'),
          if (!store.loggedIn)
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Text(
                'Bạn có thể chọn hàng trước. Đăng nhập khi đặt hàng để giữ và đồng bộ giỏ của bạn.',
              ),
            ),
          if (store.accountError != null) AccountError(store),
          if ('${store.cart?['mergeStatus']}'.startsWith('PENDING_'))
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Text(
                    'Giỏ khách chưa gộp được do vượt giới hạn số lượng hoặc số dòng. Các sản phẩm vẫn được giữ. Hãy giảm số lượng trong giỏ tài khoản rồi đồng bộ lại.',
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              await store.refreshCart();
                            } catch (error) {
                              if (context.mounted) toast(context, error);
                            }
                          },
                    child: const Text('Đồng bộ lại giỏ khách'),
                  ),
                ],
              ),
            ),
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
                                variantDisplayName(item),
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
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
                    child: CartVoucherSummary(enabled: !busy),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            store.cartItems.any((i) => i['available'] != true)
                        ? null
                        : proceed,
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
