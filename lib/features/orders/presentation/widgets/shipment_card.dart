import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/panel.dart';
import '../../domain/order_labels.dart';

class ShipmentCard extends StatelessWidget {
  final Json shipment;
  const ShipmentCard(this.shipment, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = shipment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s['deliveryMode'] == 'direct'
                  ? 'Cửa hàng giao trực tiếp'
                  : '${s['carrier'] ?? 'Đơn vị giao hàng'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            SelectableText(
              '${s['trackingCode'] ?? s['shipmentCode'] ?? 'Chưa có mã vận đơn'}',
            ),
            Text(orderStatus(s['status'])),
            if (s['driverName'] != null) Text('Người giao: ${s['driverName']}'),
            if (RegExp(r'^\+?[0-9 ()-]{8,20}$')
                .hasMatch('${s['driverPhone'] ?? ''}'))
              TextButton.icon(
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: '${s['driverPhone']}')),
                icon: const Icon(Icons.phone_outlined),
                label: Text('${s['driverPhone']}'),
              ),
            if (s['departedAt'] != null)
              Text('Khởi hành: ${dateText(s['departedAt'])}'),
            if (s['estimatedArrivalAt'] != null && s['deliveredAt'] == null)
              Text(
                'Dự kiến đến: ${dateText(s['estimatedArrivalAt'])} (có thể thay đổi)',
              ),
            if (number(s['routeDistanceMeters']) > 0)
              Text(
                'Quãng đường dự kiến: ${(number(s['routeDistanceMeters']) / 1000).toStringAsFixed(1)} km',
              ),
            if (s['deliveredAt'] != null)
              Text('Đã giao: ${dateText(s['deliveredAt'])}'),
            if ('${s['failureReason'] ?? ''}'.isNotEmpty)
              Text('Giao chưa thành công: ${s['failureReason']}'),
          ],
        ),
      ),
    );
  }
}
