import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/features/orders/presentation/order_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../../helpers/customer_fixtures.dart';

http.Response ok(dynamic data) => response(data);

Json sampleOrder({
  String status = 'pending_payment',
  String attempt = 'pending',
}) => {
  'id': 'order-a',
  'orderCode': 'DH-TEST',
  'status': status,
  'paymentMethod': 'payos',
  'paymentStatus': 'pending',
  'paymentDueAt': DateTime.now()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'pricing': {'items': [], 'subtotal': 100000, 'totalAmount': 100000},
  'payments': [
    {'id': 'payment-a', 'gateway': 'payos', 'status': attempt},
  ],
};

Future<void> showOrder(WidgetTester tester, OrganicStore store) async {
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: const MaterialApp(home: OrderScreen('order-a')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Hủy đơn hàng'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets(
    'a creating VietQR attempt is recovered via the existing API before cancellation',
    (tester) async {
      var order = sampleOrder(attempt: 'creating');
      final posts = <String>[];
      final store = customer(
        MockClient((request) async {
          if (request.url.path.endsWith('/payments/initiate')) {
            posts.add('initiate');
            expect(jsonDecode(request.body), {
              'orderId': 'order-a',
              'gateway': 'payos',
            });
            order = sampleOrder();
            return ok({
              'id': 'payment-a',
              'gateway': 'payos',
              'status': 'pending',
              'paymentUrl': 'https://pay.payos.vn/web/example',
            });
          }
          if (request.url.path.endsWith('/cancel')) {
            posts.add('cancel');
            order = sampleOrder(status: 'cancelled', attempt: 'cancelled');
            return ok(order);
          }
          if (request.url.path.endsWith('/orders/order-a')) return ok(order);
          return ok({'items': [], 'totalElements': 0});
        }),
      );
      await showOrder(tester, store);
      await tester.tap(find.text('Hủy đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy đơn'));
      await tester.pumpAndSettle();
      expect(posts, ['initiate', 'cancel']);
      await tester.scrollUntilVisible(
        find.text('Đã hủy'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text('Hủy đơn hàng'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'gateway cancellation errors stay visible and never claim the order was cancelled',
    (tester) async {
      var cancelCalls = 0;
      final store = customer(
        MockClient((request) async {
          if (request.url.path.endsWith('/cancel')) {
            cancelCalls++;
            return http.Response(
              jsonEncode({
                'message': 'Cổng thanh toán chưa xử lý được yêu cầu',
              }),
              502,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.endsWith('/orders/order-a')) {
            return ok(sampleOrder());
          }
          return ok({'items': [], 'totalElements': 0});
        }),
      );
      await showOrder(tester, store);
      await tester.tap(find.text('Hủy đơn hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy đơn'));
      await tester.pumpAndSettle();
      expect(cancelCalls, 1);
      await tester.scrollUntilVisible(
        find.text('Cổng thanh toán chưa xử lý được yêu cầu'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Cổng thanh toán chưa xử lý được yêu cầu'),
        findsOneWidget,
      );
      expect(find.text('Đã hủy'), findsNothing);
      expect(find.text('Hủy đơn hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'cancel confirmation cannot be double submitted and keeping the order makes no API mutation',
    (tester) async {
      var posts = 0;
      final store = customer(
        MockClient((request) async {
          if (request.method == 'POST') posts++;
          return ok(sampleOrder());
        }),
      );
      await showOrder(tester, store);
      await tester.tap(find.text('Hủy đơn hàng'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Hủy đơn hàng'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Giữ đơn'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Hủy đơn hàng'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
