import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../../../shared/widgets/visible_refresh.dart';
import '../../domain/delivery_estimate.dart';

class DeliveryEstimate extends StatefulWidget {
  final Json shipment;
  const DeliveryEstimate(this.shipment, {super.key});
  @override
  State<DeliveryEstimate> createState() => _DeliveryEstimateState();
}

class _DeliveryEstimateState extends State<DeliveryEstimate>
    with WidgetsBindingObserver, RouteAware {
  Timer? timer;
  ModalRoute<void>? route;
  bool foreground = true, visible = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  void syncTimer() {
    timer?.cancel();
    final deadline = estimatedDeadline(widget.shipment);
    if (foreground &&
        visible &&
        deadline != null &&
        deadline.isAfter(DateTime.now())) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!deadline.isAfter(DateTime.now())) timer?.cancel();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (route != next) {
      storefrontRoutes.unsubscribe(this);
      route = next;
      if (next != null) storefrontRoutes.subscribe(this, next);
    }
    visible = route?.isCurrent != false;
    syncTimer();
  }

  @override
  void didUpdateWidget(covariant DeliveryEstimate oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimer();
  }

  @override
  void didPushNext() {
    visible = false;
    syncTimer();
  }

  @override
  void didPopNext() {
    visible = true;
    setState(() {});
    syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && mounted) setState(() {});
    syncTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    storefrontRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipment = widget.shipment;
    if (shipmentStopped(shipment)) return const SizedBox.shrink();
    final deadline = estimatedDeadline(shipment);
    final remaining = deadline == null
        ? ''
        : deliveryCountdown(deadline, DateTime.now());
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sage,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deadline == null
                ? deliveryPendingText(shipment)
                : 'Dự kiến đến: ${deliveryTimeText(deadline)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (deadline != null) ...[
            const SizedBox(height: 10),
            Text(
              remaining.isEmpty
                  ? 'Đã đến giờ giao dự kiến'
                  : 'Thời gian còn lại dự kiến',
            ),
            Text(
              remaining.isEmpty
                  ? 'Đang chờ nhân viên xác nhận kết quả giao hàng.'
                  : remaining,
              key: const ValueKey('shipment.countdown'),
              style: remaining.isEmpty
                  ? null
                  : Theme.of(context).textTheme.headlineMedium,
            ),
            if (number(shipment['routeDistanceMeters']) > 0)
              Text(
                '${(number(shipment['routeDistanceMeters']) / 1000).toStringAsFixed(1)} km'
                '${number(shipment['routeDurationSeconds']) > 0 ? ' · Khoảng ${(number(shipment['routeDurationSeconds']) / 60).ceil()} phút di chuyển' : ''}',
              ),
            const SizedBox(height: 6),
            const Text(
              'Ước tính theo tuyến ô tô từ cửa hàng đến điểm nhận; chưa tính trung chuyển, giao thông trực tiếp hoặc các điểm dừng khác.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
