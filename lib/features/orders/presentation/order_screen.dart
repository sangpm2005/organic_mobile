import 'dart:async';

import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/orders/domain/order_labels.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/features/checkout/presentation/widgets/price_summary.dart';

import 'widgets/shipment_card.dart';

import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

import 'payment_launcher.dart';

import '../../catalog/presentation/widgets/product_photo.dart';
import '../domain/payment_policy.dart';
import '../../feedback/presentation/feedback_list_screen.dart';
import '../../returns/presentation/returns_screen.dart';
import '../../reviews/presentation/reviews_screen.dart';

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
  bool active = true;
  Future<void>? _loadPending;
  String? actionError;
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
    active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    if (!active || store == null || !store!.loggedIn) {
      return;
    }
    final pending = _loadPending;
    if (pending != null) {
      await pending;
      if (force && mounted) await load();
      return;
    }
    final request = fetchOrder();
    _loadPending = request;
    try {
      await request;
    } finally {
      if (identical(_loadPending, request)) _loadPending = null;
    }
  }

  Future<void> fetchOrder() async {
    final account = store!.user?['accountId'];
    loading = true;
    try {
      final result = await store!.orderService.detail(widget.id);
      if (mounted && store!.loggedIn && store!.user?['accountId'] == account) {
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
    if (busy || order == null || !canCancelOrder(order!)) return;
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
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
      await load(force: true);
      if (!mounted || order == null || !canCancelOrder(order!)) return;
      final creating = objects(order!['payments'])
          .where(
            (payment) =>
                payment['gateway'] == order!['paymentMethod'] &&
                payment['status'] == 'creating',
          )
          .firstOrNull;
      final due = DateTime.tryParse('${order!['paymentDueAt']}');
      if (creating != null && due != null && due.isAfter(DateTime.now())) {
        // Recover the existing attempt using the API's persisted reference;
        // the cancellation endpoint can then close that payment normally.
        await store!.orderService.initiate(widget.id, '${creating['gateway']}');
      }
      final cancelled = await store!.orderService.cancel(widget.id);
      if (mounted && cancelled['id'] == widget.id) {
        setState(() => order = cancelled);
      }
      await load(force: true);
      await store!.refreshAccount(force: true);
    } catch (e) {
      if (mounted) {
        setState(() => actionError = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> pay() async {
    if (busy || order == null || !canPayOrder(order!)) return;
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
      final payment = await store!.orderService.initiate(
        widget.id,
        '${order!['paymentMethod']}',
      );
      await load(force: true);
      if (!mounted || !store!.loggedIn) return;
      await openPaymentPortal(payment);
    } catch (e) {
      if (mounted) {
        setState(() => actionError = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> verifyPayment() async {
    if (busy) return;
    final paypal = order?['paymentMethod'] == 'paypal';
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
      if (paypal) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xác nhận thanh toán PayPal'),
            content: const Text(
              'Bạn đã chấp thuận thanh toán trên PayPal? Ứng dụng sẽ yêu cầu máy chủ kiểm tra và hoàn tất thu tiền nếu giao dịch đã được chấp thuận.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Chưa'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đã chấp thuận'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final latest = await store!.orderService.detail(widget.id);
      final payment = objects(latest['payments'])
          .where(
            (p) =>
                p['gateway'] == latest['paymentMethod'] &&
                [
                  'pending',
                  'creating',
                  'capturing',
                  'closing',
                ].contains(p['status']),
          )
          .firstOrNull;
      if (payment != null && latest['paymentStatus'] != 'paid') {
        final checked = await store!.orderService.sync('${payment['id']}');
        if (paypal &&
            checked['gateway'] == 'paypal' &&
            ['pending', 'capturing'].contains(checked['status'])) {
          await store!.orderService.capturePaypal('${payment['id']}');
        }
      }
      await load(force: true);
      await store!.refreshAccount(force: true);
      if (mounted) {
        toast(
          context,
          order?['paymentStatus'] == 'paid'
              ? 'Máy chủ đã xác nhận thanh toán.'
              : 'Chưa có xác nhận thanh toán thành công. Vui lòng kiểm tra lại sau.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => actionError = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
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
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductPhoto('${item['imageUrl'] ?? ''}'),
                      ),
                      title: Text('${item['productName']}'),
                      subtitle: Text(
                        '${item['variantName']} × ${item['quantity']}',
                      ),
                      trailing: Text(money(item['lineAmount'])),
                    ),
                  ),
                  const Divider(),
                  PriceSummary(object(order!['pricing'])),
                  Text(
                    (order!['paymentMethod'] == 'payos'
                            ? 'VietQR'
                            : '${order!['paymentMethod']}'.toUpperCase()) +
                        (order!['paymentStatus'] == 'paid'
                            ? ' · Đã thanh toán'
                            : ' · ${orderStatus(order!['paymentStatus'])}'),
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 20),
                  ...objects(order!['shipments']).map(ShipmentCard.new),
                  Text(
                    'Điểm đã tích: ${order!['pointsEarned'] ?? 0}',
                    style: const TextStyle(color: moss),
                  ),
                  if (actionError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (canPayOrder(order!) &&
                      order!['paymentMethod'] != 'cod') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : verifyPayment,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(
                        order!['paymentMethod'] == 'paypal'
                            ? 'Xác nhận thanh toán PayPal'
                            : 'Kiểm tra thanh toán',
                      ),
                    ),
                  ],
                  if (order!['paymentDueAt'] != null &&
                      order!['status'] == 'pending_payment')
                    Text('Hạn thanh toán: ${dateText(order!['paymentDueAt'])}'),
                  if (canPayOrder(order!) &&
                      order!['paymentMethod'] != 'cod') ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : pay,
                      child: Text(
                        order!['paymentMethod'] == 'payos'
                            ? 'Hiện mã VietQR'
                            : order!['paymentMethod'] == 'paypal'
                            ? 'Thanh toán PayPal'
                            : 'Tiếp tục thanh toán',
                      ),
                    ),
                  ],
                  if (canCancelOrder(order!)) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy ? null : cancel,
                      child: const Text('Hủy đơn hàng'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Hỗ trợ sau mua',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () => open(
                      context,
                      FeedbackListScreen(orderId: widget.id),
                      account: true,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Phản hồi về đơn hàng'),
                  ),
                  TextButton.icon(
                    onPressed: () => open(
                      context,
                      ReturnsScreen(orderId: widget.id),
                      account: true,
                    ),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Yêu cầu đổi trả / hoàn tiền'),
                  ),
                  if (['delivered', 'completed'].contains(order!['status']))
                    TextButton.icon(
                      onPressed: () =>
                          open(context, const ReviewsScreen(), account: true),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Đánh giá sản phẩm đã nhận'),
                    ),
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
