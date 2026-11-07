import '../../../core/utils/json.dart';

class VoucherRecommendation {
  final Json voucher;
  final bool fitsCart, verified;
  final double saving;
  const VoucherRecommendation(
    this.voucher, {
    required this.fitsCart,
    required this.saving,
    this.verified = false,
  });

  factory VoucherRecommendation.forCart(
    Json voucher,
    List<Json> items,
    double subtotal,
  ) {
    final names = (voucher['productNames'] as List? ?? [])
        .map((v) => '$v'.trim().toLowerCase())
        .toSet();
    var eligible = subtotal;
    if (names.isNotEmpty) {
      eligible = items
          .where(
            (i) => names.contains(
              '${i['productName'] ?? ''}'.trim().toLowerCase(),
            ),
          )
          .fold<double>(
            0,
            (sum, i) => sum + number(i['unitPrice']) * number(i['quantity']),
          );
    }
    // Estimates only: preview checks quotas, stock, IDs and other promotions.
    var amount = voucher['discountType'] == 'percentage'
        ? (eligible * number(voucher['discountValue']) / 100).roundToDouble()
        : number(voucher['discountValue']);
    if (voucher['maxDiscountAmount'] != null) {
      amount = amount.clamp(0, number(voucher['maxDiscountAmount'])).toDouble();
    }
    amount = amount.clamp(0, eligible.clamp(0, double.infinity)).toDouble();
    final fits =
        voucher['usable'] == true &&
        subtotal >= number(voucher['minOrderValue']) &&
        eligible > 0 &&
        amount > 0 &&
        (voucher['batchCodes'] as List? ?? []).isEmpty;
    return VoucherRecommendation(voucher, fitsCart: fits, saving: amount);
  }

  VoucherRecommendation checked(double amount) => VoucherRecommendation(
    voucher,
    fitsCart: amount > 0,
    saving: amount,
    verified: true,
  );
  VoucherRecommendation rejected() => VoucherRecommendation(
    voucher,
    fitsCart: false,
    saving: saving,
    verified: true,
  );

  static int compare(VoucherRecommendation a, VoucherRecommendation b) {
    int group(VoucherRecommendation r) => r.voucher['usable'] != true
        ? 2
        : r.fitsCart
        ? 0
        : 1;
    final category = group(a).compareTo(group(b));
    if (category != 0) return category;
    final amount = b.saving.compareTo(a.saving);
    if (amount != 0) return amount;
    final expiry = '${a.voucher['expiresAt'] ?? '9999'}'.compareTo(
      '${b.voucher['expiresAt'] ?? '9999'}',
    );
    return expiry != 0
        ? expiry
        : '${a.voucher['voucherCode']}'.compareTo(
            '${b.voucher['voucherCode']}',
          );
  }
}
