import 'package:intl/intl.dart';

import '../../../core/utils/json.dart';

bool shipmentStopped(Json shipment) =>
    const {
      'delivered',
      'failed',
      'delivery_failed',
      'returned',
      'cancelled',
    }.contains(shipment['status']) ||
    shipment['deliveredAt'] != null;

/// Timestamps without an offset are supplied in the store's Vietnam timezone.
DateTime? deliveryDeadline(dynamic value) {
  final text = '${value ?? ''}';
  if (text.isEmpty) return null;
  return DateTime.tryParse(
    RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$').hasMatch(text) ? text : '$text+07:00',
  )?.toUtc();
}

DateTime? estimatedDeadline(Json shipment) =>
    shipment['estimateStatus'] == 'estimated' && !shipmentStopped(shipment)
    ? deliveryDeadline(shipment['estimatedArrivalAt'])
    : null;

String deliveryTimeText(DateTime value) =>
    DateFormat('dd/MM/yyyy · HH:mm')
        .format(value.toUtc().add(const Duration(hours: 7)));

String deliveryCountdown(DateTime deadline, DateTime now) {
  final seconds = (deadline.difference(now).inMilliseconds / 1000).ceil();
  if (seconds <= 0) return '';
  final hours = seconds ~/ 3600, minutes = seconds % 3600 ~/ 60;
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${hours > 0 ? '${pad(hours)}:' : ''}${pad(minutes)}:${pad(seconds % 60)}';
}

String deliveryPendingText(Json shipment) {
  if (shipment['status'] == 'pending') {
    return 'Sẽ tính giờ đến dự kiến khi xác nhận đã lấy hàng.';
  }
  return switch (shipment['estimateStatus']) {
    'location_required' =>
      'Cửa hàng cần xác nhận vị trí nhận hàng để tính giờ đến.',
    'store_location_required' || 'service_not_configured' =>
      'Cửa hàng đang cập nhật thông tin tính thời gian giao.',
    'calculating' => 'Đang tính giờ đến dự kiến từ bản đồ…',
    'rate_limited' =>
      'Chưa cập nhật được giờ đến dự kiến. Vui lòng kiểm tra lại sau.',
    _ => 'Chưa tính được giờ đến dự kiến. Cửa hàng sẽ kiểm tra lại.',
  };
}
