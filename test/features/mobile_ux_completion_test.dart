import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/auth/presentation/register_screen.dart';
import 'package:organic_mobile/features/account/presentation/profile_screen.dart';
import 'package:organic_mobile/features/catalog/data/product_stock_cache.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/category_picker.dart';
import 'package:organic_mobile/features/checkout/data/checkout_repository.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/features/feedback/data/feedback_repository.dart';
import 'package:organic_mobile/features/orders/data/orders_repository.dart';
import 'package:organic_mobile/features/orders/data/payment_return_links.dart';
import 'package:organic_mobile/features/shopping_chat/data/shopping_chat_repository.dart';
import 'package:organic_mobile/shared/widgets/note_dialog.dart';
import 'package:organic_mobile/shared/widgets/visible_refresh.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'order search fetches old pages and rejects an account switch mid-fetch',
    () async {
      final pages = <String>[];
      final store = customer(
        MockClient((r) async {
          pages.add(r.url.queryParameters['page']!);
          final page = int.parse(r.url.queryParameters['page']!);
          return response({
            'content': [
              {'id': 'order-$page'},
            ],
            'totalElements': 2,
            'totalPages': 2,
          });
        }),
      );
      expect((await OrdersRepository(store.api).all()).map((o) => o['id']), [
        'order-0',
        'order-1',
      ]);
      expect(pages, ['0', '1']);
      store.dispose();
      late OrganicApi api;
      api = OrganicApi(
        client: MockClient((_) async {
          api.setSession('another-user', 'refresh');
          return response({'content': [], 'totalElements': 0});
        }),
      );
      api.setSession('first-user', 'refresh');
      await expectLater(
        OrdersRepository(api).all(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('stock requests share in-flight calls, cap concurrency and cache public data', () async {
    final requests = <Completer<http.Response>>[];
    var active = 0, maxActive = 0, calls = 0;
    final api = OrganicApi(
      client: MockClient((_) async {
        calls++;
        active++;
        if (active > maxActive) maxActive = active;
        final c = Completer<http.Response>();
        requests.add(c);
        final result = await c.future;
        active--;
        return result;
      }),
    );
    final cache = ProductStockCache.forApi(api);
    final futures = [for (var i = 0; i < 8; i++) cache.get('p$i')];
    final duplicate = cache.get('p0');
    await Future<void>.delayed(Duration.zero);
    expect(requests.length, 3);
    for (var i = 0; i < 8; i++) {
      requests[i].complete(
        response({
          'availableQuantity': {'v': i + 1},
        }),
      );
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait(futures);
    await duplicate;
    expect(maxActive, 3);
    expect(calls, 8);
    await cache.get('p0');
    expect(calls, 8);
  });

  test(
    'location supports exact coordinates and rejects out-of-range points',
    () async {
      final api = OrganicApi(
        client: MockClient(
          (_) async => throw StateError('No request expected'),
        ),
      );
      final repo = CheckoutRepository(api);
      final point = (await repo.resolve(' 10.7799129, 106.699902 ')).single;
      expect(point['latitude'], 10.7799129);
      expect(point['longitude'], 106.699902);
      expect(point['precise'], true);
      expect(CheckoutRepository.coordinates('91, 106'), isNull);
      expect(CheckoutRepository.coordinates('10, 181'), isNull);
      expect(CheckoutRepository.coordinates('NaN, 106'), isNull);
    },
  );

  test('feedback filters are sent to server with pagination', () async {
    final store = customer(
      MockClient((r) async {
        expect(r.url.queryParameters['page'], '3');
        expect(r.url.queryParameters['feedbackType'], 'delivery');
        expect(r.url.queryParameters['search'], 'Giao hàng');
        expect(r.url.queryParameters['status'], 'resolved');
        return response({'content': [], 'totalElements': 0});
      }),
    );
    await FeedbackRepository(store.api).list(
      3,
      feedbackType: 'delivery',
      search: 'Giao hàng',
      status: 'resolved',
    );
    store.dispose();
  });

  test(
    'AI sends bounded history and discards a reply after account changes',
    () async {
      late OrganicApi api;
      api = OrganicApi(
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          final turns = body['history'] as List;
          expect(turns.length, 8);
          expect((turns.first['text'] as String).length, 2000);
          expect(body['message'], 'Tìm rau');
          api.setSession('other-user', 'refresh');
          return response({
            'answer': 'Private response',
            'orders': [
              {'id': 'private'},
            ],
          });
        }),
      );
      api.setSession('user-a', 'refresh');
      await expectLater(
        ShoppingChatRepository(api).ask('  Tìm rau  ', [
          for (var i = 0; i < 12; i++)
            {'role': i.isEven ? 'user' : 'assistant', 'text': 'x' * 2300},
        ], authenticated: true),
        throwsA(anything),
      );
    },
  );

  test('payment links only navigate by one UUID and never interpret gateway success', () {
    const id = '11c4f23b-e1ef-4f1c-8563-e4052214f296';
    expect(
      paymentReturnOrder(
        Uri.parse('organicfood://payment-return?orderId=$id&status=paid'),
      ),
      id,
    );
    for (final text in [
      'https://evil.example/payment-return?orderId=$id',
      'organicfood://other?orderId=$id',
      'organicfood://payment-return?orderId=invalid',
      'organicfood://payment-return?orderId=$id&orderId=$id',
      'organicfood://payment-return/not-allowed?orderId=$id',
    ]) {
      expect(paymentReturnOrder(Uri.parse(text)), isNull);
    }
  });

  testWidgets(
    'accept confirmation has no note field and needs an explicit tap',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                child: const Text('Đồng ý'),
                onPressed: () async {
                  result = await askNote(
                    ctx,
                    'Đồng ý phương án',
                    collectNote: false,
                    required: false,
                    description: 'Xác nhận phương án hiện tại.',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(result, isNull);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(result, '');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'category picker drills into children and selects a parent scope explicitly',
    (tester) async {
      Map<String, dynamic>? selected;
      final rows = [
        {'id': 'food', 'name': 'Thực phẩm'},
        {'id': 'vegetable', 'parentId': 'food', 'name': 'Rau củ'},
        {'id': 'leaf', 'parentId': 'vegetable', 'name': 'Rau lá'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                child: const Text('Chọn'),
                onPressed: () async {
                  selected = await chooseCategory(ctx, rows);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(find.text('Rau lá'), findsNothing);
      await tester.tap(find.text('Thực phẩm'));
      await tester.pumpAndSettle();
      expect(find.text('Rau củ'), findsOneWidget);
      expect(find.text('Rau lá'), findsNothing);
      await tester.tap(find.text('Tất cả Thực phẩm'));
      await tester.pumpAndSettle();
      expect(selected?['id'], 'food');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background refresh stops for hidden tab and refreshes when shown',
    (tester) async {
      var calls = 0;
      Future<void> refresh() async {
        calls++;
      }

      Widget app(bool active) => MaterialApp(
        home: VisibleRefresh(
          active: active,
          refresh: refresh,
          child: const Text('Catalog'),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 0);
      await tester.pumpWidget(app(true));
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'checkout auto-resolves a unique precise saved address and sends real coordinates',
    (tester) async {
      Map<String, dynamic>? preview;
      var geocodes = 0;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/delivery-locations')) {
            geocodes++;
            return response([
              {
                'label': 'Điểm nhận',
                'latitude': 10.7799,
                'longitude': 106.6999,
                'precise': true,
              },
            ]);
          }
          if (r.url.path.endsWith('/preview')) {
            preview = jsonDecode(r.body);
            return response({'totalAmount': 45000});
          }
          return response({'cod': true});
        }),
      );
      store.profile = {
        'addresses': [
          {
            'receiverName': 'Nguyễn An',
            'receiverPhone': '0901234567',
            'streetAddress': '2 Công xã Paris',
            'ward': 'Sài Gòn',
            'province': 'Hồ Chí Minh',
          },
        ],
      };
      store.cart = {
        'items': [
          {'variantId': 'v', 'quantity': 1},
        ],
      };
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(geocodes, 1);
      await tester.scrollUntilVisible(
        find.text('Kiểm tra giá & tồn kho'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kiểm tra giá & tồn kho'));
      await tester.pumpAndSettle();
      expect(preview?['deliveryLatitude'], 10.7799);
      expect(preview?['deliveryLongitude'], 106.6999);
      expect(preview?.containsKey('invoiceEmail'), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'registration limits OTP to six digits and enforces resend countdown',
    (tester) async {
      var sends = 0;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/resend-otp')) sends++;
          return response({});
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: RegisterScreen(verifyExisting: true)),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('register.email')),
        'an@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register.otp')),
        '12x345678',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('register.otp')))
            .controller!
            .text,
        '123456',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Gửi lại mã OTP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi lại mã OTP'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(find.text('Gửi lại mã sau 60 giây'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Gửi lại mã sau 60 giây'),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('Gửi lại mã OTP'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('profile retains the user-approved 9 to 10 digit phone rule', (
    tester,
  ) async {
    final store = customer(MockClient((_) async => response({})));
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('profile.phoneNumber')),
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('profile.phoneNumber')),
              matching: find.byType(TextField),
            ),
          )
          .keyboardType,
      TextInputType.phone,
    );
    expect(field.validator!('0912345678'), isNull);
    expect(field.validator!('912345678'), isNull);
    expect(field.validator!('09123456789'), isNotNull);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('profile.dateOfBirth')),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      true,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
