import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/checkout/presentation/widgets/payment_methods.dart';
import 'package:organic_mobile/features/orders/domain/payment_policy.dart';
import 'package:organic_mobile/features/orders/presentation/payment_launcher.dart';

void main() {
  testWidgets(
    'VietQR and PayPal are separate choices with exactly one selection',
    (tester) async {
      var selected = 'payos';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => PaymentMethods(
                available: const {'payos': true, 'paypal': true},
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('VietQR'), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('checkout.payment.paypal')));
      await tester.pump();
      expect(selected, 'paypal');
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const ValueKey('checkout.payment.paypal')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const ValueKey('checkout.payment.payos')),
            )
            .selected,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('VietQR opens the payOS QR page in an in-app browser while PayPal opens separately', () async {
    for (final gateway in ['payos', 'paypal']) {
      final calls = <LaunchMode>[];
      await openPaymentPortal(
        {
          'gateway': gateway,
          'status': 'pending',
          'paymentUrl': gateway == 'payos'
              ? 'https://pay.payos.vn/web/test'
              : 'https://www.sandbox.paypal.com/checkoutnow?token=test',
        },
        opener: (url, mode) async {
          calls.add(mode);
          return true;
        },
      );
      expect(calls, [
        gateway == 'payos'
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      ]);
    }
  });

  test('VietQR falls back to the external browser if native browser view is unavailable', () async {
    final calls = <LaunchMode>[];
    await openPaymentPortal(
      {
        'gateway': 'payos',
        'status': 'pending',
        'paymentUrl': 'https://pay.payos.vn/web/test',
      },
      opener: (_, mode) async {
        calls.add(mode);
        if (mode == LaunchMode.inAppBrowserView) {
          throw PlatformException(code: 'unsupported');
        }
        return true;
      },
    );
    expect(calls, [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]);
  });

  test('no browser opens for an untrusted or mismatched gateway URL', () async {
    var calls = 0;
    await expectLater(
      openPaymentPortal(
        {
          'gateway': 'payos',
          'status': 'pending',
          'paymentUrl': 'https://www.paypal.com/checkout',
        },
        opener: (_, _) async {
          calls++;
          return true;
        },
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
  });

  test('orders that require payment review expose neither repayment nor cancellation', () {
    final order = {
      'status': 'pending_payment',
      'paymentStatus': 'pending',
      'paymentMethod': 'payos',
      'payments': [
        {'gateway': 'payos', 'status': 'requires_review'},
      ],
    };
    expect(canPayOrder(order), isFalse);
    expect(canCancelOrder(order), isFalse);
  });
}
