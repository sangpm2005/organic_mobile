import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/rewards/presentation/voucher_picker_screen.dart';
import 'package:organic_mobile/features/rewards/presentation/widgets/voucher_card.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';
import 'voucher_recommendation_test.dart' show voucher, items;

OrganicStore makeStore(http.Client client, {bool recipient = false}) {
  final store = OrganicStore(api: OrganicApi(client: client));
  store.user = {'accountId': 'a'};
  store.api.setSession('a', 'r');
  store.cart = {'subtotal': 300000, 'items': items(300000)};
  if (recipient) {
    store.profile = {
      'addresses': [
        {
          'receiverName': 'Khách hàng',
          'receiverPhone': '0901234567',
          'streetAddress': '123 Đường A',
        },
      ],
    };
  }
  return store;
}

Future<void> mount(
  WidgetTester tester,
  OrganicStore store, {
  Json? payload,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: organicTheme(),
        home: VoucherPickerScreen(checkoutPayload: payload),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> order(WidgetTester tester) =>
    (tester.widget<ListView>(find.byType(ListView)).childrenDelegate
            as SliverChildListDelegate)
        .children
        .whereType<VoucherCard>()
        .map((c) => '${c.voucher['voucherCode']}')
        .toList();

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('changing accounts never reuses the previous wallet cache', (
    tester,
  ) async {
    final store = makeStore(
      MockClient(
        (r) async => response({
          'totalElements': 1,
          'items': [
            voucher(
              r.headers['Authorization'] == 'Bearer a'
                  ? 'ACCOUNT_A'
                  : 'ACCOUNT_B',
              10000,
            ),
          ],
        }),
      ),
    );
    await mount(tester, store);
    expect(order(tester), ['ACCOUNT_A']);
    store.user = {'accountId': 'b'};
    store.api.setSession('b', 'refresh-b');
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(order(tester), ['ACCOUNT_B']);
    expect(find.text('ACCOUNT_A'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'picker ranks 300k discounts, rejects the 500k voucher without shortfall text, and reranks at 500k',
    (tester) async {
      final store = makeStore(
        MockClient(
          (r) async => response({
            'totalElements': 3,
            'items': [
              voucher('MIN500', 100000, minimum: 500000),
              voucher('TEN', 10, type: 'percentage'),
              voucher('FIXED50', 50000),
            ],
          }),
        ),
      );
      store.selectVoucher('OLD');
      await mount(tester, store);
      expect(order(tester), ['FIXED50', 'TEN', 'MIN500']);
      final excluded = find.byKey(const ValueKey('voucher.choice.MIN500'));
      await tester.scrollUntilVisible(
        excluded,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      final use = find.descendant(of: excluded, matching: find.text('Sử dụng'));
      await tester.ensureVisible(use);
      await tester.pumpAndSettle();
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(
        find.text('Voucher không phù hợp với giỏ hàng hiện tại.'),
        findsOneWidget,
      );
      expect(find.byType(VoucherPickerScreen), findsOneWidget);
      expect(store.selectedVoucherCode, 'OLD');
      expect(find.textContaining('Còn thiếu'), findsNothing);
      store.cart = {'subtotal': 500000, 'items': items(500000)};
      store.notifyListeners();
      await tester.pumpAndSettle();
      expect(order(tester).first, 'MIN500');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'all wallet pages are loaded before globally sorting the best voucher',
    (tester) async {
      final pages = <int>[];
      final store = makeStore(
        MockClient((r) async {
          final page = int.parse(r.url.queryParameters['page']!);
          pages.add(page);
          return response({
            'totalElements': 21,
            'items': page == 0
                ? List.generate(20, (i) => voucher('SMALL$i', 1000))
                : [voucher('BEST', 90000)],
          });
        }),
      );
      await mount(tester, store);
      expect(pages, [0, 1]);
      expect(order(tester).length, 21);
      expect(order(tester).first, 'BEST');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'server previews rank actual savings and push quota failures below usable vouchers',
    (tester) async {
      final checked = <String>[];
      final store = makeStore(
        MockClient((r) async {
          if (r.url.path.endsWith('/vouchers')) {
            return response({
              'totalElements': 3,
              'items': [
                voucher('A', 90000),
                voucher('B', 50000),
                voucher('C', 30000),
              ],
            });
          }
          final code = '${jsonDecode(r.body)['voucherCode']}';
          checked.add(code);
          if (code == 'A') return response({}, 409);
          return response({
            'voucherCode': code,
            'voucherDiscount': code == 'B' ? 5000 : 20000,
          });
        }),
        recipient: true,
      );
      await mount(tester, store);
      expect(checked.toSet(), {'A', 'B', 'C'});
      expect(order(tester), ['C', 'B', 'A']);
      expect(find.text('Giảm 20.000 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'checkout picker uses its current receiver, quantity and promotion instead of the saved address',
    (tester) async {
      Json? checked;
      final store = makeStore(
        MockClient((r) async {
          if (r.url.path.endsWith('/vouchers')) {
            return response({
              'totalElements': 1,
              'items': [voucher('VC', 10000)],
            });
          }
          checked = object(jsonDecode(r.body));
          return response({'voucherCode': 'VC', 'voucherDiscount': 10000});
        }),
        recipient: true,
      );
      await mount(
        tester,
        store,
        payload: {
          'items': [
            {'variantId': 'v', 'quantity': 2},
          ],
          'receiverName': 'Người nhận mới',
          'receiverPhone': '0912345678',
          'shippingAddress': '99 Địa chỉ mới',
          'paymentMethod': 'paypal',
          'promotionCode': 'PROMO',
          'points': 10,
        },
      );
      expect(checked?['receiverName'], 'Người nhận mới');
      expect(checked?['shippingAddress'], '99 Địa chỉ mới');
      expect(checked?['promotionCode'], 'PROMO');
      expect(checked?['points'], 0);
      expect(objects(checked?['items']).single['quantity'], 2);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'an old preview cannot restore the old order after basket changes',
    (tester) async {
      final old = Completer<http.Response>();
      var previews = 0;
      final store = makeStore(
        MockClient((r) async {
          if (r.url.path.endsWith('/vouchers')) {
            return response({
              'totalElements': 1,
              'items': [voucher('VC', 10000)],
            });
          }
          previews++;
          if (previews == 1) return old.future;
          return response({'voucherCode': 'VC', 'voucherDiscount': 10000});
        }),
        recipient: true,
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: VoucherPickerScreen()),
        ),
      );
      await tester.pump();
      store.cart = {'subtotal': 500000, 'items': items(500000)};
      store.notifyListeners();
      await tester.pump();
      old.complete(response({'voucherCode': 'VC', 'voucherDiscount': 1}));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng 500.000 đ'), findsOneWidget);
      expect(find.text('Giảm 1 đ'), findsNothing);
      expect(find.text('Giảm 10.000 đ'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
