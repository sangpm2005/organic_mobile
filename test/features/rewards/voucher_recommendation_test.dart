import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/features/rewards/domain/voucher_recommendation.dart';
import 'package:organic_mobile/core/utils/json.dart';

Json voucher(
  String code,
  double discount, {
  String type = 'fixed_amount',
  double minimum = 0,
  double? cap,
  bool usable = true,
  List<String> products = const [],
}) => {
  'voucherCode': code,
  'name': code,
  'discountType': type,
  'discountValue': discount,
  'minOrderValue': minimum,
  'maxDiscountAmount': cap,
  'usable': usable,
  'status': usable ? 'available' : 'reserved',
  'productNames': products,
};
List<Json> items(double total) => [
  {
    'productName': 'Rau xanh',
    'variantId': 'v',
    'quantity': 1,
    'unitPrice': total,
  },
];

void main() {
  final wallet = [
    voucher('MIN500', 100000, minimum: 500000),
    voucher('TEN', 10, type: 'percentage'),
    voucher('CAP40', 50, type: 'percentage', cap: 40000),
    voucher('FIXED50', 50000, minimum: 300000),
  ];
  List<VoucherRecommendation> rank(double total) =>
      wallet
          .map((v) => VoucherRecommendation.forCart(v, items(total), total))
          .toList()
        ..sort(VoucherRecommendation.compare);

  test(
    '300k basket prioritizes effective saving, with the 500k threshold last',
    () {
      final result = rank(300000);
      expect(result.map((r) => r.voucher['voucherCode']), [
        'FIXED50',
        'CAP40',
        'TEN',
        'MIN500',
      ]);
      expect(result.map((r) => r.saving), [50000, 40000, 30000, 100000]);
      expect(result.last.fitsCart, false);
    },
  );
  test('raising the basket to 500k brings the newly eligible best voucher to the top', () {
    final result = rank(500000);
    expect(result.first.voucher['voucherCode'], 'MIN500');
    expect(result.first.fitsCart, true);
    expect(result.first.saving, 100000);
  });
  test(
    'a large fixed voucher cannot save more than the eligible goods total',
    () {
      final result = VoucherRecommendation.forCart(
        voucher('LARGE', 500000),
        items(300000),
        300000,
      );
      expect(result.saving, 300000);
    },
  );
  test('product scope limits percentage savings while minimum value uses the whole basket', () {
    final result = VoucherRecommendation.forCart(
      voucher(
        'VEG',
        10,
        type: 'percentage',
        minimum: 300000,
        products: ['Rau xanh'],
      ),
      [
        {'productName': 'Rau xanh', 'unitPrice': 100000, 'quantity': 1},
        {'productName': 'Gạo', 'unitPrice': 200000, 'quantity': 1},
      ],
      300000,
    );
    expect(result.fitsCart, true);
    expect(result.saving, 10000);
  });
  test('unrelated products and unavailable vouchers cannot be applied', () {
    expect(
      VoucherRecommendation.forCart(
        voucher('RICE', 10000, products: ['Gạo']),
        items(300000),
        300000,
      ).fitsCart,
      false,
    );
    expect(
      VoucherRecommendation.forCart(
        voucher('RESERVED', 90000, usable: false),
        items(300000),
        300000,
      ).fitsCart,
      false,
    );
  });
  test('server checked savings override estimates and rejected vouchers fall below valid ones', () {
    final result = rank(300000);
    final sorted = [
      result[0].rejected(),
      result[1].checked(5000),
      result[2].checked(25000),
    ]..sort(VoucherRecommendation.compare);
    expect(sorted.map((r) => r.voucher['voucherCode']), [
      'TEN',
      'CAP40',
      'FIXED50',
    ]);
    expect(sorted.first.verified, true);
  });
}
