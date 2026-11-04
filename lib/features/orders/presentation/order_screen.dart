import 'dart:async';

import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
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
import 'package:url_launcher/url_launcher.dart';

import '../../catalog/presentation/widgets/product_photo.dart';
import '../domain/payment_policy.dart';

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

  Future<void> load() async {
    if (!active || loading || store == null || !store!.loggedIn) {
      return;
    }
    loading = true;
    try {
      final result = await store!.orderService.detail(widget.id);
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
      await store!.orderService.cancel(widget.id);
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
      final payment = await store!.orderService.initiate(
        widget.id,
        '${order!['paymentMethod']}',
      );
      await load();
      final url = paymentRedirect(payment);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
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

  Future<void> verifyPayment() async {
    final paypal = order?['paymentMethod'] == 'paypal';
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
    setState(() => busy = true);
    try {
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
        if (paypal && ['pending', 'capturing'].contains(checked['status'])) {
          await store!.orderService.capturePaypal('${payment['id']}');
        }
      }
      await load();
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
      if (mounted) toast(context, e);
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
                    '${order!['paymentMethod']}'.toUpperCase() +
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
                  if (order!['paymentMethod'] != 'cod' &&
                      order!['paymentStatus'] != 'paid') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : verifyPayment,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Đã thanh toán / Kiểm tra kết quả'),
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
                      child: const Text('Tiếp tục thanh toán'),
                    ),
                  ],
                  if (canCancelOrder(order!)) ...[
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
