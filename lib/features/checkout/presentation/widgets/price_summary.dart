import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/widgets/amount_row.dart';

class PriceSummary extends StatelessWidget {
  final Json quote;
  const PriceSummary(this.quote, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AmountRow('Tiền hàng', quote['subtotal']),
      AmountRow(
        'Khuyến mãi',
        -number(quote['publicPromotionDiscount'] ?? quote['promotionDiscount']),
      ),
      if (number(quote['voucherDiscount']) > 0)
        AmountRow(
          'Voucher ${quote['voucherCode'] ?? ''}',
          -number(quote['voucherDiscount']),
        ),
      AmountRow('Đổi điểm', -number(quote['pointsDiscount'])),
      AmountRow('Phí giao hàng', quote['shippingFee']),
      const Divider(),
      AmountRow('Tổng thanh toán', quote['totalAmount'], total: true),
      if (quote['vatIncluded'] == true)
        const Text('Đã bao gồm VAT', style: TextStyle(fontSize: 11)),
    ],
  );
}
