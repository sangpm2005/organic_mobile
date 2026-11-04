import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/panel.dart';

class VoucherCard extends StatelessWidget {
  final Json voucher;
  final Widget? action;
  const VoucherCard(this.voucher, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    final p = voucher;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p['name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              p['discountType'] == 'percentage'
                  ? 'Giảm ${p['discountValue']}%'
                  : 'Giảm ${money(p['discountValue'])}',
            ),
            if (p['maxDiscountAmount'] != null)
              Text('Giảm tối đa ${money(p['maxDiscountAmount'])}'),
            Text('Đơn từ ${money(p['minOrderValue'])}'),
            if ('${p['description'] ?? ''}'.isNotEmpty)
              Text('${p['description']}'),
            if ((p['productNames'] as List? ?? []).isNotEmpty)
              Text('Sản phẩm: ${(p['productNames'] as List).join(', ')}'),
            if ((p['batchCodes'] as List? ?? []).isNotEmpty)
              Text('Lô áp dụng: ${(p['batchCodes'] as List).join(', ')}'),
            for (final product in objects(p['requiredProducts']))
              Text('Combo: ${product['productName']} × ${product['quantity']}'),
            Text(
              'Hạn dùng: ${dateText(p['expiresAt'] ?? p['endDate'] ?? p['endsAt'])}',
            ),
            if (p['voucherCode'] != null) ...[
              SelectableText('${p['voucherCode']}'),
              Text(
                const {
                      'available': 'Còn hiệu lực',
                      'reserved': 'Đang giữ cho đơn hàng',
                      'used': 'Đã sử dụng',
                      'expired': 'Đã hết hạn',
                    }[p['status']] ??
                    '${p['status']}',
              ),
            ],
            if (p['voucherCode'] == null &&
                p['pointsCost'] == null &&
                p['promotionCode'] != null)
              SelectableText('Mã: ${p['promotionCode']}'),
            ?action,
          ],
        ),
      ),
    );
  }
}
