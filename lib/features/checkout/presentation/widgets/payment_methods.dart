import 'package:flutter/material.dart';

class PaymentMethods extends StatelessWidget {
  final Map<String, dynamic> available;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  const PaymentMethods({
    super.key,
    required this.available,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: value,
    onChanged: (next) {
      if (enabled && next != null && available[next] == true) onChanged(next);
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Phương thức thanh toán',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final entry in const {
          'cod': (
            'Thanh toán khi nhận hàng (COD)',
            'Trả tiền khi nhận hàng.',
            Icons.payments_outlined,
          ),
          'payos': (
            'VietQR',
            'Chuyển khoản ngân hàng qua mã QR của payOS.',
            Icons.qr_code_2,
          ),
          'paypal': (
            'PayPal',
            'Đăng nhập và xác nhận riêng trên PayPal.',
            Icons.account_balance_wallet_outlined,
          ),
          'vnpay': (
            'VNPay',
            'Thanh toán qua ngân hàng hoặc ví VNPay.',
            Icons.account_balance_outlined,
          ),
          'stripe': (
            'Thẻ quốc tế (Stripe)',
            'Thanh toán bằng thẻ trên Stripe.',
            Icons.credit_card_outlined,
          ),
        }.entries)
          if (available[entry.key] == true || entry.key == value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: entry.key == value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RadioListTile<String>(
                  key: ValueKey('checkout.payment.${entry.key}'),
                  value: entry.key,
                  enabled: enabled && available[entry.key] == true,
                  secondary: Icon(entry.value.$3),
                  title: Text(entry.value.$1),
                  subtitle: Text(
                    available[entry.key] == true
                        ? entry.value.$2
                        : 'Hiện chưa khả dụng',
                  ),
                  selected: value == entry.key,
                ),
              ),
            ),
      ],
    ),
  );
}
