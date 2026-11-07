import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/core/utils/formatters.dart';

void main() {
  test('zero discounts have no negative sign while actual deductions stay negative', () {
    for (final value in [0, 0.0, -0.0, '-0', null]) {
      expect(money(value), '0 đ');
    }
    expect(money(-10000), '-10.000 đ');
    expect(money(44000), '44.000 đ');
    expect(money(0.4), '0,4 đ');
  });
}
