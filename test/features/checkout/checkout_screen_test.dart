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
import 'package:organic_mobile/features/address/data/address_directory.dart';
import 'package:organic_mobile/features/address/presentation/address_picker_screen.dart';
import 'package:organic_mobile/features/orders/domain/payment_policy.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../../helpers/customer_fixtures.dart';

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
    'checkout picks a searchable two-level address and sends it in the price preview',
    (tester) async {
      await tester.runAsync(() => AddressDirectory.load());
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? preview;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/checkout/preview')) {
            preview = jsonDecode(r.body);
            return response({
              'totalAmount': 100000,
              'estimatedEarnedPoints': 1,
            });
          }
          return response({'cod': true});
        }),
      );
      store.cart = {
        'items': [
          {'variantId': 'v', 'quantity': 1},
        ],
      };
      store.profile = {
        'addresses': [
          {
            'receiverName': 'Nguyễn An',
            'receiverPhone': '0901234567',
            'streetAddress': '12 Lê Lợi',
            'ward': 'Bến Nghé',
            'province': 'Hồ Chí Minh',
            'district': '1',
          },
        ],
      };
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('checkout.shippingAddress'));
      expect(
        tester.widget<TextFormField>(field).controller?.text,
        '12 Lê Lợi, Bến Nghé, Hồ Chí Minh',
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byType(AddressPickerScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('address.search')),
        'ben nghe hcm',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('address.suggestion.26740')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('address.streetAddress')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('address.streetAddress')),
        '24 Nguyễn Huệ',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('address.confirm')));
      await tester.tap(find.byKey(const ValueKey('address.confirm')));
      await tester.pumpAndSettle();
      const expectedAddress =
          '24 Nguyễn Huệ, Phường Sài Gòn, Thành phố Hồ Chí Minh';
      expect(
        tester.widget<TextFormField>(field).controller?.text,
        expectedAddress,
      );
      await tester.scrollUntilVisible(
        find.text('Kiểm tra giá & tồn kho'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kiểm tra giá & tồn kho'));
      await tester.pumpAndSettle();
      expect(preview?['shippingAddress'], expectedAddress);
      expect(preview?['items'], [
        {'variantId': 'v', 'quantity': 1},
      ]);
      await tester.scrollUntilVisible(
        find.text('Xác nhận đặt hàng'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Xác nhận đặt hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
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
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Thử lại đơn này'),
      );
      await tester.pumpAndSettle();
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
