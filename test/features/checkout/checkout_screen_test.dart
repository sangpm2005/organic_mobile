import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/features/orders/domain/payment_policy.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('payment redirects use the same gateway allowlist as the website', () {
    expect(
      paymentRedirect({
        'gateway': 'payos',
        'status': 'pending',
        'paymentUrl': 'https://pay.payos.vn/web/link',
      }).host,
      'pay.payos.vn',
    );
    for (final url in [
      'http://pay.payos.vn/web/link',
      'https://pay.payos.vn.evil.example/link',
      'https://user:pass@pay.payos.vn/link',
      'https://checkout.stripe.com/link',
    ]) {
      expect(
        () => paymentRedirect({
          'gateway': 'payos',
          'status': 'pending',
          'paymentUrl': url,
        }),
        throwsA(isA<ApiException>()),
      );
    }
    expect(
      () => paymentRedirect({
        'gateway': 'payos',
        'status': 'paid',
        'paymentUrl': 'https://pay.payos.vn/web/link',
      }),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets(
    'restored checkout keeps exact legacy body and key even if PayOS is now disabled',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final payload = {
        'items': [
          {'variantId': 'variant', 'quantity': 1},
        ],
        'receiverName': 'Nguyễn An',
        'receiverPhone': '0901234567',
        'shippingAddress': '123 Nguyễn Trãi, TP.HCM',
        'note': '',
        'promotionCode': 'lowercase-legacy',
        'points': 0,
        'paymentMethod': 'payos',
      };
      var attempts = 0;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/orders')) {
              attempts++;
              expect(r.headers['Idempotency-Key'], 'original-key');
              expect(jsonDecode(r.body), payload);
              return http.Response(jsonEncode({'message': 'Thử lại sau'}), 503);
            }
            return http.Response(
              jsonEncode({
                'data': {'payos': false},
              }),
              200,
            );
          }),
        ),
      );
      store.user = {'accountId': 'a'};
      store.api.setSession('access', 'refresh');
      store.pendingCheckout = {
        'key': 'original-key',
        'payload': payload,
        'quote': {'totalAmount': 100000},
      };
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Thử lại đơn này'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Thử lại đơn này'));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(store.pendingCheckout?['key'], 'original-key');
      expect(store.pendingCheckout?['payload'], payload);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
