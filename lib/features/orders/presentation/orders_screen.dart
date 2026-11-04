import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/orders/domain/order_labels.dart';
import 'package:organic_mobile/features/orders/presentation/order_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/account_error.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loggedIn) {
      return const LoginGate(
        'Theo dõi hành trình giao hàng và xem lại những lần mua cùng Mộc.',
      );
    }
    return RefreshIndicator(
      onRefresh: store.refreshAccount,
      child: ListView(
        children: [
          const Heading('Hành trình của bạn', eyebrow: 'Đơn hàng'),
          if (store.accountError != null) AccountError(store),
          if (store.orders.isEmpty && store.accountError == null)
            const EmptyState(
              'Chưa có đơn hàng',
              'Đơn hàng từ ứng dụng và website sẽ cùng xuất hiện tại đây.',
              icon: Icons.receipt_long_outlined,
            ),
          ...store.orders.map(
            (order) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  store.readOrder(order);
                  open(context, OrderScreen('${order['id']}'), account: true);
                },
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${order['orderCode']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: moss),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        orderStatus(order['status']),
                        style: const TextStyle(
                          color: moss,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        objects(object(order['pricing'])['items'])
                            .map(
                              (i) => '${i['productName']} × ${i['quantity']}',
                            )
                            .join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateText(order['orderedAt']),
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
                            ),
                          ),
                          Text(
                            money(object(order['pricing'])['totalAmount']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: moss,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (store.hasMoreOrders)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                onPressed: store.loadingMoreOrders
                    ? null
                    : () async {
                        try {
                          await store.loadMoreOrders();
                        } catch (e) {
                          if (context.mounted) {
                            toast(context, e);
                          }
                        }
                      },
                child: Text(
                  store.loadingMoreOrders ? 'Đang tải…' : 'Xem đơn cũ hơn',
                ),
              ),
            ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
