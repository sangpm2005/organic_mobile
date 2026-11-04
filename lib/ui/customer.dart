import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'auth.dart';
import 'checkout.dart';
import 'theme.dart';
import 'widgets.dart';

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
          const Heading('Giỏ xanh của bạn', eyebrow: 'Mộc đồng hành'),
          if (store.accountError != null) _AccountError(store),
          if (store.cartItems.isEmpty)
            const EmptyState(
              'Giỏ hàng còn đang trống',
              'Ghé vườn nhà Mộc và chọn một chút tươi lành cho hôm nay.',
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

class _AccountError extends StatelessWidget {
  final OrganicStore store;
  const _AccountError(this.store);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Panel(
      child: Column(
        children: [
          Text(store.accountError ?? 'Chưa tải được dữ liệu.'),
          TextButton(
            onPressed: store.refreshAccount,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

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
          if (store.accountError != null) _AccountError(store),
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

class OrderScreen extends StatefulWidget {
  final String id;
  const OrderScreen(this.id, {super.key});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with WidgetsBindingObserver {
  OrganicStore? store;
  Json? order;
  String? error;
  Timer? timer;
  bool loading = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (store == null) {
      store = StoreScope.of(context);
      load();
      timer = Timer.periodic(const Duration(seconds: 20), (_) => load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
    }
  }

  Future<void> load() async {
    if (loading || store == null || !store!.loggedIn) {
      return;
    }
    loading = true;
    try {
      final result = object(
        await store!.api.request('GET', '/orders/${widget.id}'),
      );
      if (mounted) {
        setState(() {
          order = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      loading = false;
    }
  }

  Future<void> cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text(
          'Đơn sẽ được hủy theo điều kiện hiện tại của cửa hàng. Hàng và điểm đang giữ sẽ được giải phóng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ đơn'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await store!.api.request('POST', '/orders/${widget.id}/cancel');
      await load();
      await store!.refreshAccount(force: true);
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

  Future<void> pay() async {
    setState(() => busy = true);
    try {
      final payment = object(
        await store!.api.request(
          'POST',
          '/payments/initiate',
          body: {'orderId': widget.id, 'gateway': order!['paymentMethod']},
        ),
      );
      final url = Uri.tryParse('${payment['paymentUrl']}');
      if (url == null ||
          url.scheme != 'https' ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const ApiException('Chưa mở được cổng thanh toán.');
      }
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
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        actions: [
          IconButton(
            tooltip: 'Cập nhật trạng thái',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !current.loggedIn
          ? const LoginGate('Đăng nhập để xem đơn hàng của bạn.')
          : order == null
          ? error == null
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    'Chưa tải được đơn hàng',
                    error!,
                    action: TextButton(
                      onPressed: load,
                      child: const Text('Thử lại'),
                    ),
                  )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Panel(
                    color: sage,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 32,
                          color: moss,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          orderStatus(order!['status']),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          '${order!['orderCode']}',
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dateText(order!['orderedAt']),
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Giao đến',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${order!['receiverName']} · ${order!['receiverPhone']}',
                  ),
                  Text(
                    '${order!['shippingAddress']}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Trong giỏ xanh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...objects(object(order!['pricing'])['items']).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['productName']}'),
                      subtitle: Text(
                        '${item['variantName']} × ${item['quantity']}',
                      ),
                      trailing: Text(money(item['lineAmount'])),
                    ),
                  ),
                  const Divider(),
                  AmountRow('Tiền hàng', object(order!['pricing'])['subtotal']),
                  AmountRow(
                    'Khuyến mãi',
                    -number(object(order!['pricing'])['promotionDiscount']),
                  ),
                  AmountRow(
                    'Đổi điểm',
                    -number(object(order!['pricing'])['pointsDiscount']),
                  ),
                  AmountRow(
                    'Giao hàng',
                    object(order!['pricing'])['shippingFee'],
                  ),
                  AmountRow(
                    'Tổng cộng',
                    object(order!['pricing'])['totalAmount'],
                    total: true,
                  ),
                  Text(
                    '${order!['paymentMethod']}'.toUpperCase() +
                        (order!['paymentStatus'] == 'paid'
                            ? ' · Đã thanh toán'
                            : ' · ${orderStatus(order!['paymentStatus'])}'),
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 20),
                  ...objects(order!['shipments']).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['carrier']} · ${s['trackingCode'] ?? 'Chưa có mã vận đơn'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(orderStatus(s['status'])),
                            if (s['driverName'] != null)
                              Text(
                                'Giao hàng: ${s['driverName']} · ${s['driverPhone'] ?? ''}',
                              ),
                            if (s['deliveredAt'] != null)
                              Text('Đã giao: ${dateText(s['deliveredAt'])}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Điểm đã tích: ${order!['pointsEarned'] ?? 0}',
                    style: const TextStyle(color: moss),
                  ),
                  if (order!['status'] == 'pending_payment' &&
                      order!['paymentMethod'] != 'cod') ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : pay,
                      child: const Text('Tiếp tục thanh toán'),
                    ),
                  ],
                  if ([
                        'confirmed',
                        'pending_payment',
                      ].contains(order!['status']) &&
                      order!['paymentStatus'] != 'paid') ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy ? null : cancel,
                      child: const Text('Hủy đơn hàng'),
                    ),
                  ],
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
    );
  }
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mộc thành viên')),
      body: !store.loggedIn
          ? const LoginGate(
              'Tích điểm từ đơn hoàn tất và dùng điểm để nhận ưu đãi.',
            )
          : RefreshIndicator(
              onRefresh: store.refreshAccount,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  if (store.accountError != null) _AccountError(store),
                  Panel(
                    color: ink,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.spa_outlined, color: sage, size: 32),
                        const SizedBox(height: 18),
                        const Text(
                          'ĐIỂM XANH CỦA BẠN',
                          style: TextStyle(
                            color: sage,
                            letterSpacing: 2,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${store.rewards?['available'] ?? '—'}',
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 52,
                            color: surface,
                          ),
                        ),
                        Text(
                          'Đang giữ: ${store.rewards?['reserved'] ?? 0} điểm',
                          style: const TextStyle(color: sage, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Panel(
                    child: Text(
                      'Mỗi ${money(store.rewards?['earnPerVnd'] ?? 100000)} của đơn hoàn tất tích 1 điểm.\n1 điểm đổi ${money(store.rewards?['redeemValue'] ?? 2000)}. Tối đa ${store.rewards?['redeemLimit'] ?? 50} điểm mỗi đơn.\nBạn chọn số điểm muốn dùng ở bước đặt hàng.',
                      style: const TextStyle(height: 1.8, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Lịch sử điểm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (store.transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Chưa có giao dịch điểm. Những lựa chọn lành đầu tiên đang chờ bạn.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ...store.transactions.map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: sage,
                        child: Icon(Icons.eco_outlined, color: moss),
                      ),
                      title: Text(
                        '${t['note'] ?? const {'earn': 'Tích điểm', 'redeem': 'Đổi điểm', 'reserve': 'Giữ điểm', 'release': 'Hoàn điểm đang giữ'}[t['type']] ?? t['type']}',
                      ),
                      subtitle: Text(dateText(t['createdAt'])),
                      trailing: Text(
                        '${number(t['pointsDelta']) > 0 ? '+' : ''}${t['pointsDelta']}',
                        style: const TextStyle(
                          color: moss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Ưu đãi từ Mộc',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  if (store.promotions.isEmpty)
                    const Text(
                      'Chưa có mã ưu đãi đang hiệu lực.',
                      style: TextStyle(color: muted),
                    ),
                  ...store.promotions.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        color: sage,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${p['description'] ?? ''}'),
                            Text(
                              'Đơn từ ${money(p['minOrderValue'])} · đến ${dateText(p['endDate'])}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    '${p['promotionCode']}',
                                    style: const TextStyle(
                                      color: moss,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sao chép mã',
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: '${p['promotionCode']}',
                                      ),
                                    );
                                    toast(context, 'Đã sao chép mã.');
                                  },
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Mộc kiểm tra sản phẩm và điều kiện áp dụng ở bước đặt hàng.',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tin từ Mộc')),
      body: !store.loggedIn
          ? const LoginGate(
              'Đăng nhập để nhận cập nhật đơn hàng và xem ưu đãi dành cho bạn.',
            )
          : RefreshIndicator(
              onRefresh: store.refreshAccount,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Cập nhật đơn hàng',
                    style: TextStyle(fontFamily: 'Lora', fontSize: 25),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trạng thái mới được cập nhật khi bạn mở ứng dụng.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 18),
                  if (store.accountError != null) _AccountError(store),
                  if (store.orders.isEmpty)
                    const EmptyState(
                      'Chưa có cập nhật',
                      'Thông tin đơn hàng sẽ xuất hiện ở đây.',
                      icon: Icons.notifications_none,
                    ),
                  ...store.orders.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          store.readOrder(o);
                          open(
                            context,
                            OrderScreen('${o['id']}'),
                            account: true,
                          );
                        },
                        child: Panel(
                          color: store.readUpdates.contains(store.updateKey(o))
                              ? surface
                              : sage,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: moss,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderStatus(o['status']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${o['orderCode']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: muted,
                                      ),
                                    ),
                                    Text(
                                      dateText(o['orderedAt']),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!store.readUpdates.contains(
                                store.updateKey(o),
                              ))
                                const Icon(Icons.circle, size: 8, color: moss),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => open(context, const RewardsScreen()),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Xem điểm thưởng & ưu đãi'),
                  ),
                ],
              ),
            ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loggedIn) {
      return const LoginGate(
        'Một tài khoản, cùng giỏ hàng và điểm thưởng trên web lẫn app.',
      );
    }
    return RefreshIndicator(
      onRefresh: store.refreshAccount,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Heading('Góc nhỏ của bạn', eyebrow: 'Mộc thành viên'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Panel(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: sage,
                    child: Icon(Icons.person_outline, size: 30, color: moss),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${store.profile?['fullName'] ?? store.user?['fullName'] ?? ''}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${store.profile?['email'] ?? store.user?['email'] ?? ''}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (store.accountError != null) _AccountError(store),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.loyalty_outlined, color: moss),
            title: const Text('Điểm xanh & ưu đãi'),
            subtitle: Text('${store.rewards?['available'] ?? 0} điểm khả dụng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const RewardsScreen()),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.person_outline, color: moss),
            title: const Text('Thông tin cá nhân'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const ProfileScreen(), account: true),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.location_on_outlined, color: moss),
            title: const Text('Địa chỉ nhận hàng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const AddressesScreen(), account: true),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.notifications_none, color: moss),
            title: const Text('Cập nhật đơn hàng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const UpdatesScreen()),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Divider(),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.support_agent_outlined, color: moss),
            title: const Text('Liên hệ cửa hàng'),
            subtitle: const Text('0344 855 913'),
            onTap: () => launchUrl(Uri.parse('tel:0344855913')),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.logout, color: moss),
            title: const Text('Đăng xuất'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất khỏi Mộc?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Ở lại'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await store.logout();
              }
            },
          ),
          const SizedBox(height: 20),
          const Center(child: Brand()),
          const SizedBox(height: 12),
          const Text(
            'Mộc Organic · Phiên bản 0.1.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in ['fullName', 'phoneNumber', 'email', 'dateOfBirth'])
      k: TextEditingController(),
  };
  bool initialized = false, busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final p = StoreScope.of(context).profile;
      for (final e in fields.entries) {
        e.value.text = '${p?[e.key] ?? ''}';
      }
      initialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    final store = StoreScope.of(context);
    try {
      await store.api.request(
        'PUT',
        '/customers/me',
        body: {
          for (final e in fields.entries)
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        },
      );
      await store.refreshAccount(force: true);
      if (mounted) {
        toast(context, 'Đã cập nhật thông tin.');
        Navigator.pop(context);
      }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin cá nhân')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          for (final e in {
            'fullName': 'Họ và tên',
            'phoneNumber': 'Số điện thoại',
            'email': 'Email',
            'dateOfBirth': 'Ngày sinh (yyyy-MM-dd)',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('profile.${e.key}'),
                controller: fields[e.key],
                enabled: !busy,
                decoration: InputDecoration(labelText: e.value),
                validator: (v) {
                  if (e.key == 'fullName' && (v == null || v.trim().isEmpty)) {
                    return 'Nhập họ và tên.';
                  }
                  if (e.key == 'email' &&
                      (v ?? '').isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!)) {
                    return 'Email chưa hợp lệ.';
                  }
                  if (e.key == 'dateOfBirth' &&
                      (v ?? '').isNotEmpty &&
                      (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v!) ||
                          DateTime.tryParse(v)
                                  ?.toIso8601String()
                                  .substring(0, 10) !=
                              v ||
                          DateTime.parse(v).isAfter(DateTime.now()))) {
                    return 'Nhập ngày theo yyyy-MM-dd.';
                  }
                  return null;
                },
              ),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Lưu thông tin'),
          ),
        ],
      ),
    ),
  );
}

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        addresses = objects(StoreScope.of(context).profile?['addresses']);
    return Scaffold(
      appBar: AppBar(title: const Text('Địa chỉ nhận hàng')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          ...addresses.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['label'] ?? 'Địa chỉ'}${a['isDefault'] == true ? ' · Mặc định' : ''}',
                      style: const TextStyle(
                        color: moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${a['receiverName']} · ${a['receiverPhone']}'),
                    Text(
                      [
                        a['streetAddress'],
                        a['ward'],
                        a['district'],
                        a['province'],
                      ].where((e) => e != null && '$e'.isNotEmpty).join(', '),
                      style: const TextStyle(color: muted),
                    ),
                    TextButton(
                      onPressed: () =>
                          open(context, AddressForm(address: a), account: true),
                      child: const Text('Chỉnh sửa'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (addresses.isEmpty)
            const EmptyState(
              'Chưa có địa chỉ',
              'Lưu địa chỉ để đặt hàng nhanh hơn.',
              icon: Icons.location_on_outlined,
            ),
          FilledButton.icon(
            onPressed: () => open(context, const AddressForm(), account: true),
            icon: const Icon(Icons.add),
            label: const Text('Thêm địa chỉ'),
          ),
          if (store.accountError != null) _AccountError(store),
        ],
      ),
    );
  }
}

class AddressForm extends StatefulWidget {
  final Json? address;
  const AddressForm({super.key, this.address});
  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final k in [
      'label',
      'receiverName',
      'receiverPhone',
      'province',
      'district',
      'ward',
      'streetAddress',
    ])
      k: TextEditingController(text: '${widget.address?[k] ?? ''}'),
  };
  late bool isDefault = widget.address?['isDefault'] == true;
  bool busy = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    final store = StoreScope.of(context);
    try {
      final id = widget.address?['id'];
      await store.api.request(
        id == null ? 'POST' : 'PUT',
        '/customers/me/addresses${id == null ? '' : '/$id'}',
        body: {
          for (final e in fields.entries) e.key: e.value.text.trim(),
          'isDefault': isDefault,
        },
      );
      await store.refreshAccount(force: true);
      if (mounted) {
        Navigator.pop(context);
      }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.address == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          for (final e in {
            'label': 'Tên địa chỉ (Nhà, Cơ quan…)',
            'receiverName': 'Người nhận',
            'receiverPhone': 'Số điện thoại',
            'province': 'Tỉnh / Thành phố',
            'district': 'Quận / Huyện',
            'ward': 'Phường / Xã',
            'streetAddress': 'Số nhà, tên đường',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('address.${e.key}'),
                controller: fields[e.key],
                enabled: !busy,
                decoration: InputDecoration(labelText: e.value),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập ${e.value.toLowerCase()}.'
                    : null,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đặt làm địa chỉ mặc định'),
            value: isDefault,
            onChanged: busy ? null : (v) => setState(() => isDefault = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Lưu địa chỉ'),
          ),
        ],
      ),
    ),
  );
}
