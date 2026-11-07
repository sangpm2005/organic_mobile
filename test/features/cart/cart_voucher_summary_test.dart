import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/cart/presentation/widgets/cart_voucher_summary.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';

const address = {
  'isDefault': true,
  'receiverName': 'Khách hàng',
  'receiverPhone': '0901234567',
  'streetAddress': '123 Đinh Tiên Hoàng',
  'province': 'TP.HCM',
};
const cart = {
  'subtotal': 100000,
  'items': [
    {'variantId': 'v', 'quantity': 1, 'available': true},
  ],
};
const quote = {
  'subtotal': 100000,
  'voucherCode': 'VC10',
  'voucherDiscount': 10000,
  'publicPromotionDiscount': 0,
  'pointsDiscount': 0,
  'shippingFee': 0,
  'totalAmount': 90000,
};

OrganicStore makeStore(
  MockClient client, {
  bool guest = false,
  bool hasAddress = true,
}) {
  final store = OrganicStore(api: OrganicApi(client: client));
  if (!guest) {
    store.user = {'accountId': 'a'};
    store.api.setSession('access', 'refresh');
  }
  store.cart = Map.of(cart);
  store.profile = {
    'addresses': hasAddress ? [address] : [],
  };
  return store;
}

Future<void> mount(WidgetTester tester, OrganicStore store) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: organicTheme(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: const [CartVoucherSummary()],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> apply(WidgetTester tester, [String value = ' vc10 ']) async {
  await tester.enterText(
    find.byKey(const ValueKey('cart.voucher.code')),
    value,
  );
  await tester.tap(find.byKey(const ValueKey('cart.voucher.apply')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'cart previews a voucher with the real items and saved recipient then passes it to checkout',
    (tester) async {
      var requests = 0;
      final store = makeStore(
        MockClient((r) async {
          if (r.url.path.endsWith('/checkout/preview')) {
            requests++;
            final body = jsonDecode(r.body);
            expect(body['voucherCode'], 'VC10');
            expect(body['points'], 0);
            expect(body['items'], [
              {'variantId': 'v', 'quantity': 1},
            ]);
            expect(body['receiverName'], address['receiverName']);
            expect(body['shippingAddress'], contains('Đinh Tiên Hoàng'));
            return response(quote);
          }
          return response({'cod': true});
        }),
      );
      await mount(tester, store);
      await apply(tester);
      expect(requests, 1);
      expect(store.selectedVoucherCode, 'VC10');
      expect(find.text('Đã áp dụng voucher VC10.'), findsOneWidget);
      expect(find.text('-10.000 đ'), findsOneWidget);
      expect(find.text('90.000 đ'), findsOneWidget);
      expect(find.text('-0 đ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkout.voucherCode')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('checkout.voucherCode')),
            )
            .controller!
            .text,
        'VC10',
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'an invalid or silently ignored voucher never displays a discount or overwrites the old selection',
    (tester) async {
      final store = makeStore(
        MockClient(
          (r) async =>
              response({...quote, 'voucherCode': null, 'voucherDiscount': 0}),
        ),
      );
      store.selectVoucher('OLD');
      await mount(tester, store);
      await apply(tester, 'INVALID');
      expect(store.selectedVoucherCode, 'OLD');
      expect(find.textContaining('Voucher không phù hợp'), findsOneWidget);
      expect(find.text('90.000 đ'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'typing a 500k-only voucher for a 100k cart without an address cannot bypass the conditions',
    (tester) async {
      final store = makeStore(
        MockClient(
          (r) async => response({
            'totalElements': 1,
            'items': [
              {
                'voucherCode': 'MIN500',
                'usable': true,
                'discountType': 'fixed_amount',
                'discountValue': 100000,
                'minOrderValue': 500000,
              },
            ],
          }),
        ),
        hasAddress: false,
      );
      store.selectVoucher('OLD');
      await mount(tester, store);
      await apply(tester, 'MIN500');
      expect(store.selectedVoucherCode, 'OLD');
      expect(
        find.text('Voucher không phù hợp với giỏ hàng hiện tại.'),
        findsOneWidget,
      );
      expect(find.textContaining('Còn thiếu'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  for (final guest in [true, false]) {
    testWidgets(
      'a selected voucher without recipient stays a draft (guest=$guest)',
      (tester) async {
        var requests = 0;
        final store = makeStore(
          MockClient((r) async {
            requests++;
            return response({
              'totalElements': 1,
              'items': [
                {
                  'voucherCode': 'VC10',
                  'usable': true,
                  'discountType': 'fixed_amount',
                  'discountValue': 10000,
                  'minOrderValue': 0,
                },
              ],
            });
          }),
          guest: guest,
          hasAddress: false,
        );
        await mount(tester, store);
        await apply(tester);
        expect(requests, guest ? 0 : 1);
        expect(store.selectedVoucherCode, 'VC10');
        expect(find.textContaining('Đã chọn voucher VC10.'), findsOneWidget);
        expect(find.textContaining('Đã áp dụng voucher'), findsNothing);
        expect(find.text('100.000 đ'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('cart.voucher.remove')));
        await tester.pumpAndSettle();
        expect(store.selectedVoucherCode, '');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('cart.voucher.code')),
              )
              .controller!
              .text,
          '',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }

  testWidgets(
    'wallet selection cannot use reserved vouchers and applies an available voucher',
    (tester) async {
      final store = makeStore(
        MockClient((r) async {
          if (r.url.path.endsWith('/vouchers')) {
            return response({
              'totalElements': 2,
              'items': [
                {
                  'name': 'Đang giữ cho đơn',
                  'voucherCode': 'RESERVED',
                  'status': 'reserved',
                  'usable': false,
                },
                {
                  'name': 'Voucher dùng được',
                  'voucherCode': 'VC10',
                  'status': 'available',
                  'usable': true,
                  'discountType': 'fixed_amount',
                  'discountValue': 10000,
                },
              ],
            });
          }
          return response(quote);
        }),
      );
      await mount(tester, store);
      await tester.tap(find.byKey(const ValueKey('cart.voucher.wallet')));
      await tester.pumpAndSettle();
      expect(find.text('RESERVED'), findsOneWidget);
      expect(find.text('Sử dụng'), findsOneWidget);
      await tester.ensureVisible(find.text('Sử dụng'));
      await tester.tap(find.text('Sử dụng'));
      await tester.pumpAndSettle();
      expect(store.selectedVoucherCode, 'VC10');
      expect(find.text('90.000 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('a late preview cannot apply to changed cart contents', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final store = makeStore(MockClient((r) async => pending.future));
    await mount(tester, store);
    await tester.enterText(
      find.byKey(const ValueKey('cart.voucher.code')),
      'VC10',
    );
    await tester.tap(find.byKey(const ValueKey('cart.voucher.apply')));
    await tester.pump();
    store.cart = {
      ...cart,
      'subtotal': 200000,
      'items': [
        {'variantId': 'v', 'quantity': 2},
      ],
    };
    store.notifyListeners();
    pending.complete(response(quote));
    await tester.pumpAndSettle();
    expect(store.selectedVoucherCode, '');
    expect(find.text('90.000 đ'), findsNothing);
    expect(
      find.textContaining('Giỏ hàng hoặc địa chỉ đã thay đổi'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'a verified discount disappears immediately when cart quantity changes',
    (tester) async {
      final store = makeStore(MockClient((r) async => response(quote)));
      await mount(tester, store);
      await apply(tester);
      store.cart = {...cart, 'subtotal': 200000};
      store.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('90.000 đ'), findsNothing);
      expect(find.text('200.000 đ'), findsOneWidget);
      expect(find.text('Đã áp dụng voucher VC10.'), findsNothing);
      expect(store.selectedVoucherCode, 'VC10');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
