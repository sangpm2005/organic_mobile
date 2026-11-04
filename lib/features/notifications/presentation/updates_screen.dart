import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/widgets/login_gate.dart';
import '../../orders/presentation/order_screen.dart';
import '../../promotions/presentation/promotions_screen.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/theme/organic_theme.dart';
import '../../../shared/widgets/account_error.dart';
import '../../../shared/widgets/panel.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool busy = false;
  Future<void> read(Json update) async {
    final store = StoreScope.of(context);
    try {
      await store.readUpdate(update);
      if (!mounted) return;
      // Route only to customer screens; never navigate using server-supplied URLs.
      if (update['kind'] == 'order') {
        open(context, OrderScreen('${update['orderId']}'), account: true);
      }
      if (update['kind'] == 'promotion') {
        open(context, const PromotionsScreen());
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Future<void> more() async {
    final store = StoreScope.of(context);
    setState(() => busy = true);
    try {
      await store.loadMoreInbox();
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tin từ Mộc')),
      body: !store.loggedIn
          ? const LoginGate('Đăng nhập để nhận cập nhật đơn hàng và ưu đãi.')
          : RefreshIndicator(
              onRefresh: () => store.refreshAccount(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Đơn hàng, thông báo và khuyến mãi được cập nhật khi bạn sử dụng ứng dụng.',
                  ),
                  const SizedBox(height: 16),
                  if (store.accountError != null) AccountError(store),
                  if (store.updates.isEmpty) const Text('Chưa có thông báo.'),
                  for (final n in store.updates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => read(n),
                        borderRadius: BorderRadius.circular(20),
                        child: Panel(
                          color: n['read'] == true ? surface : sage,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${n['title']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('${n['message']}'),
                              Text(
                                dateText(n['createdAt']),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                              if (n['read'] != true)
                                const Text(
                                  'Chưa đọc',
                                  style: TextStyle(color: moss, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (store.hasMoreInbox)
                    TextButton(
                      onPressed: busy ? null : more,
                      child: Text(busy ? 'Đang tải…' : 'Thông báo trước đó'),
                    ),
                  if (store.hasMoreOrders)
                    TextButton(
                      onPressed: store.loadingMoreOrders
                          ? null
                          : store.loadMoreOrders,
                      child: const Text('Cập nhật đơn hàng trước đó'),
                    ),
                  TextButton(
                    onPressed: () => open(context, const PromotionsScreen()),
                    child: const Text('Xem ưu đãi & combo'),
                  ),
                ],
              ),
            ),
    );
  }
}
