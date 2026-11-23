import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../domain/sale_selection.dart';

class SaleExpiry extends StatelessWidget {
  final dynamic date;
  const SaleExpiry(this.date, {super.key});
  @override
  Widget build(BuildContext context) => date == null || '$date'.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_available_outlined, size: 17, color: moss),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Hạn sử dụng: ${saleDate(date)}',
                  style: const TextStyle(fontSize: 12, color: ink),
                ),
              ),
            ],
          ),
        );
}

class SaleOfferNotice extends StatelessWidget {
  final Json? selected;
  final bool comboOnly;
  const SaleOfferNotice({super.key, this.selected, this.comboOnly = false});
  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return Text(
        comboOnly
            ? 'Quy cách này hiện chỉ có trong combo. Xem chương trình mua kèm bên dưới.'
            : 'Quy cách này hiện chưa có hàng có thể đặt.',
      );
    }
    final campaign = '${selected!['promotionId'] ?? ''}'.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SaleExpiry(
          campaign ? selected!['expiryDate'] : selected!['nearestExpiryDate'],
        ),
        if (campaign)
          const Text(
            'Giá ưu đãi áp dụng cho lượng hàng có hạn sử dụng trên.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
      ],
    );
  }
}
