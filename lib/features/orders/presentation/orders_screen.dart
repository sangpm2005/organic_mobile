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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final search = TextEditingController();
  String status = '';
  DateTimeRange? dates;
  List<Json>? all;
  String? error;
  bool busy = false;
  int request = 0;
  int? session;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (session != store.api.sessionVersion) {
      session = store.api.sessionVersion;
      all = null;
      error = null;
      busy = false;
      request++;
    }
  }

  @override
  void dispose() {
    request++;
    search.dispose();
    super.dispose();
  }

  Future<void> find() async {
    final store = StoreScope.of(context);
    final version = ++request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await store.orderService.all();
      if (mounted &&
          version == request &&
          session == store.api.sessionVersion) {
        setState(() => all = result);
      }
    } catch (e) {
      if (mounted && version == request) setState(() => error = '$e');
    } finally {
      if (mounted && version == request) setState(() => busy = false);
    }
  }

  List<Json> filtered(List<Json> rows) => rows.where((o) {
    final text =
        '${o['orderCode']} ${objects(object(o['pricing'])['items']).map((i) => i['productName']).join(' ')}'
            .toLowerCase();
    final date = DateTime.tryParse('${o['orderedAt']}')?.toLocal();
    return text.contains(search.text.trim().toLowerCase()) &&
        (status.isEmpty || o['status'] == status) &&
        (dates == null ||
            date != null &&
                !date.isBefore(dates!.start) &&
                date.isBefore(dates!.end.add(const Duration(days: 1))));
  }).toList();
  Future<void> pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: dates,
      helpText: 'Thời gian đặt hàng',
    );
    if (!mounted || picked == null) return;
    setState(() => dates = picked);
    await find();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loggedIn) {
      return const LoginGate(
        'Theo dõi hành trình giao hàng và xem lại những lần mua cùng organicfood.',
      );
    }
    final rows = filtered(all ?? store.orders);
    return RefreshIndicator(
      onRefresh: () async {
        await store.refreshAccount();
        await find();
      },
      child: ListView(
        children: [
          const Heading('Hành trình của bạn', eyebrow: 'Đơn hàng'),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => find(),
                  decoration: InputDecoration(
                    labelText: 'Tìm mã đơn hoặc sản phẩm',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Tìm tất cả đơn',
                      onPressed: busy ? null : find,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái đơn',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tất cả trạng thái'),
                    ),
                    for (final s in [
                      'pending_payment',
                      'confirmed',
                      'preparing',
                      'shipping',
                      'delivered',
                      'completed',
                      'cancelled',
                      'expired',
                    ])
                      DropdownMenuItem(value: s, child: Text(orderStatus(s))),
                  ],
                  onChanged: (v) {
                    setState(() => status = v ?? '');
                    find();
                  },
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: pickDates,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        dates == null
                            ? 'Chọn khoảng ngày'
                            : '${dateText(dates!.start.toIso8601String())} – ${dateText(dates!.end.toIso8601String())}',
                      ),
                    ),
                    if (dates != null)
                      TextButton(
                        onPressed: () {
                          setState(() => dates = null);
                          find();
                        },
                        child: const Text('Bỏ lọc ngày'),
                      ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          if (store.accountError != null) AccountError(store),
          if (rows.isEmpty &&
              store.accountError == null &&
              !busy &&
              error == null)
            const EmptyState(
              'Chưa có đơn hàng',
              'Đơn hàng từ ứng dụng và website sẽ cùng xuất hiện tại đây.',
              icon: Icons.receipt_long_outlined,
            ),
          ...rows.map(
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
          if (all == null && store.hasMoreOrders)
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
