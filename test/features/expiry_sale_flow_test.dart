import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/catalog/domain/sale_selection.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_quick_actions.dart';
import 'package:organic_mobile/features/catalog/presentation/product_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/sale_option_picker.dart';
import 'package:organic_mobile/features/cart/presentation/cart_screen.dart';
import 'package:organic_mobile/features/cart/data/cart_checkout_payload.dart';
import 'package:organic_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:organic_mobile/features/promotions/presentation/widgets/promotion_products.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/features/orders/presentation/order_screen.dart';

import '../helpers/customer_fixtures.dart';

const early = 'v~2027-02-01~offer';
const later = 'v~2027-03-01~';
Json option(
  String date, {
  String? promotion,
  int stock = 3,
  int price = 30000,
}) => {
  'variantId': 'v',
  'expiryDate': date,
  'promotionId': promotion,
  'price': price,
  'regularPrice': 45000,
  'availableQuantity': stock,
  'promotionName': promotion == null ? null : 'Ưu đãi theo hạn dùng',
  'combo': false,
};
Json cartLine(String date, {String? promotion, int quantity = 1}) => {
  'variantId': 'v',
  'quantity': quantity,
  'expiryDate': date,
  'salePromotionId': promotion,
  'productId': 'p',
  'productName': 'Nước ép táo',
  'variantName': 'Chai',
  'netQuantity': 946,
  'unitId': 'ml',
  'unitPrice': 30000,
  'lineTotal': 30000 * quantity,
  'available': true,
  'availableQuantity': 3,
};
const profile = {
  'addresses': [
    {
      'receiverName': 'Nguyễn An',
      'receiverPhone': '0901234567',
      'streetAddress': '12 Lê Lợi',
      'ward': 'Phường Sài Gòn',
      'province': 'Thành phố Hồ Chí Minh',
    },
  ],
};
const detail = {
  'id': 'p',
  'productName': 'Nước ép táo',
  'defaultVariantId': 'v',
  'variants': [
    {
      'id': 'v',
      'variantName': 'Chai',
      'netQuantity': 946,
      'unitId': 'ml',
      'sellingPrice': 45000,
      'status': 'active',
    },
  ],
};

Future<void> mount(
  WidgetTester tester,
  OrganicStore store,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: organicTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reach(
  WidgetTester tester,
  Finder target, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('BeVietnamPro')
          ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'one expiry notice fits a narrow phone with large text without date controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: organicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: paper,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    SaleOfferNotice(
                      selected: option('2027-02-01', promotion: 'offer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hạn sử dụng: 01/02/2027'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final output = File('.local/verification/expiry-sale-picker.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    },
  );

  testWidgets(
    'quick add waits for availability, rechecks stock and sends the current campaign identity',
    (tester) async {
      final pending = Completer<http.Response>();
      var opened = 0, posts = 0, reads = 0;
      Json? added;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.method == 'POST') {
              posts++;
              added = jsonDecode(r.body);
              return response({'items': [], 'totalQuantity': 1});
            }
            if (++reads == 1) return pending.future;
            return response({
              'saleOptions': [option('2027-02-01', promotion: 'offer')],
            });
          }),
        ),
      );
      await mount(
        tester,
        store,
        ProductQuickActions(
          Product.fromJson({
            'id': 'p',
            'productName': 'Nước ép táo',
            'defaultVariantId': 'v',
            'defaultPrice': 45000,
          }),
          choose: () => opened++,
        ),
      );
      await tester.tap(find.text('Thêm'));
      await tester.pump();
      pending.complete(
        response({
          'saleOptions': [option('2027-02-01', promotion: 'offer')],
        }),
      );
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(
        posts,
        1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(added, {
        'variantId': 'v',
        'quantity': 1,
        'expiryDate': '2027-02-01',
        'salePromotionId': 'offer',
      });
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'retrying a pending checkout retains exact expiry dates, offers and idempotency key',
    (tester) async {
      final payload = {
        'items': [saleItem(cartLine('2027-02-01', promotion: 'offer'))],
        'receiverName': 'Nguyễn An',
        'receiverPhone': '0901234567',
        'shippingAddress': '12 Lê Lợi, Phường Sài Gòn, Thành phố Hồ Chí Minh',
        'paymentMethod': 'cod',
        'points': 0,
        'note': '',
      };
      var attempts = 0;
      final store =
          customer(
              MockClient((r) async {
                if (r.method == 'POST' && r.url.path.endsWith('/orders')) {
                  attempts++;
                  expect(jsonDecode(r.body), payload);
                  expect(r.headers['Idempotency-Key'], 'same-expiry-order');
                  return response({}, 503);
                }
                return response({'cod': true});
              }),
            )
            ..pendingCheckout = {
              'key': 'same-expiry-order',
              'payload': payload,
              'quote': {'items': payload['items'], 'totalAmount': 30000},
            };
      await mount(tester, store, const CheckoutScreen());
      for (var i = 0; i < 2; i++) {
        await reach(tester, find.text('Thử lại đơn này'));
        await tester.tap(find.text('Thử lại đơn này'));
        await tester.pumpAndSettle();
      }
      expect(attempts, 2);
      expect(store.pendingCheckout?['payload'], payload);
      expect(store.pendingCheckout?['key'], 'same-expiry-order');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'one current campaign controls price and capacity without offering another expiry',
    (tester) async {
      Json? added;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/availability')) {
              return response({
                'saleOptions': [
                  option('2027-02-01', promotion: 'offer', stock: 1),
                  option('2027-03-01', price: 45000),
                ],
                'availableQuantity': {'v': 100},
              });
            }
            if (r.url.path.endsWith('/reviews')) {
              return response({
                'reviews': {'items': []},
              });
            }
            if (r.url.path.endsWith('/cart/items')) {
              added = jsonDecode(r.body);
              return response({'items': [], 'totalQuantity': 1});
            }
            return response(detail);
          }),
        ),
      );
      await mount(tester, store, const ProductScreen('p'));
      await reach(tester, find.text('Hạn sử dụng: 01/02/2027'));
      expect(find.text('Hạn sử dụng: 01/03/2027'), findsNothing);
      expect(find.text('Chọn hạn sử dụng / ưu đãi'), findsNothing);
      await reach(
        tester,
        find.byKey(const ValueKey('product.price')),
        delta: -200,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('product.price'))).data,
        '30.000 đ',
      );
      await reach(tester, find.byKey(const ValueKey('product.add')));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('product.increase')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('product.add')));
      await tester.pumpAndSettle();
      expect(added, {
        'variantId': 'v',
        'quantity': 1,
        'expiryDate': '2027-02-01',
        'salePromotionId': 'offer',
      });
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'a rejected campaign reloads the product as ordinary stock without retrying the cart request',
    (tester) async {
      var reads = 0, posts = 0;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/availability')) {
              return response({
                'saleOptions': [
                  if (++reads == 1) option('2027-02-01', promotion: 'offer'),
                  option('2027-03-01', price: 45000),
                ],
              });
            }
            if (r.url.path.endsWith('/reviews')) {
              return response({
                'reviews': {'items': []},
              });
            }
            if (r.method == 'POST') {
              posts++;
              return response({'message': 'Hàng đã hết'}, 409);
            }
            return response(detail);
          }),
        ),
      );
      await mount(tester, store, const ProductScreen('p'));
      await reach(tester, find.byKey(const ValueKey('product.add')));
      await tester.tap(find.byKey(const ValueKey('product.add')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(posts, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('product.add')))
            .onPressed,
        isNotNull,
      );
      await reach(tester, find.text('Hạn sử dụng: 01/03/2027'), delta: -200);
      expect(
        find.textContaining('Vui lòng chọn lại hạn sử dụng'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'same variant with two dates remains distinct; deleting targets the exact selection',
    (tester) async {
      final first = cartLine('2027-02-01', promotion: 'offer'),
          second = cartLine('2027-03-01');
      String? removed;
      final store =
          OrganicStore(
              api: OrganicApi(
                client: MockClient((r) async {
                  removed = r.url.pathSegments.last;
                  expect(r.method, 'DELETE');
                  return response({
                    'items': [second],
                    'subtotal': 30000,
                  });
                }),
              ),
            )
            ..cart = {
              'items': [first, second],
              'subtotal': 60000,
            };
      await mount(tester, store, const CartScreen(), scale: 1.5);
      expect(find.byKey(const ValueKey('cart.line.$early')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart.line.$later')), findsOneWidget);
      await reach(tester, find.byKey(const ValueKey('cart.remove.$early')));
      await tester.tap(find.byKey(const ValueKey('cart.remove.$early')));
      await tester.pumpAndSettle();
      expect(removed, early);
      expect(store.cartItems.map(saleKey), [later]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'expiry combo preserves separate dates for the same variant without duplicate dropdown values',
    (tester) async {
      Json? batch;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            batch = jsonDecode(r.body);
            return response({'items': [], 'subtotal': 0});
          }),
        ),
      );
      final offer = {
        'id': 'offer',
        'saleScope': 'expiry',
        'promotionType': 'combo',
        'products': [
          {
            'productId': 'p',
            'productName': 'Nước ép táo',
            'requiredQuantity': 2,
            'variants': [
              {
                ...option('2027-02-01', promotion: 'offer'),
                'id': 'v',
                'salePromotionId': 'offer',
                'variantName': 'Chai',
              },
              {
                ...option('2027-03-01', promotion: 'offer'),
                'id': 'v',
                'salePromotionId': 'offer',
                'variantName': 'Chai',
              },
            ],
          },
        ],
      };
      await mount(
        tester,
        store,
        SingleChildScrollView(child: PromotionProducts(offer: offer)),
      );
      final select = find.byType(DropdownButtonFormField<String>);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('HSD: 01/03/2027').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm combo vào giỏ'));
      await tester.pumpAndSettle();
      expect(batch?['items'], [
        {
          'variantId': 'v',
          'quantity': 2,
          'expiryDate': '2027-03-01',
          'salePromotionId': 'offer',
        },
      ]);
      expect(store.selectedPromotionCode, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'checkout previews and places exact dates, then removes only the purchased selections',
    (tester) async {
      var rows = [
        cartLine('2027-02-01', promotion: 'offer'),
        cartLine('2027-03-01'),
      ];
      final requested = rows.map(saleItem).toList();
      final third = cartLine('2027-04-01');
      final removed = <String>[];
      final quote = {
        'items': rows,
        'totalAmount': 60000,
        'estimatedEarnedPoints': 0,
      };
      final order = {
        'id': 'order',
        'orderCode': 'DH-TEST',
        'status': 'confirmed',
        'paymentMethod': 'cod',
        'paymentStatus': 'unpaid',
        'pricing': quote,
        'receiverName': 'Nguyễn An',
        'shipments': [],
      };
      final store =
          customer(
              MockClient((r) async {
                if (r.url.path.endsWith('/checkout/preview')) {
                  expect(jsonDecode(r.body)['items'], requested);
                  return response(quote);
                }
                if (r.url.path.endsWith('/orders') && r.method == 'POST') {
                  expect(jsonDecode(r.body)['items'], requested);
                  rows = [...rows, third];
                  return response(order);
                }
                if (r.method == 'DELETE') {
                  final key = r.url.pathSegments.last;
                  removed.add(key);
                  expect(r.url.queryParameters['expectedQuantity'], '1');
                  rows = rows.where((row) => saleKey(row) != key).toList();
                  return response({'items': rows, 'subtotal': 30000});
                }
                if (r.url.path.endsWith('/cart')) {
                  return response({'items': rows});
                }
                if (r.url.path.endsWith('/customers/me')) {
                  return response(profile);
                }
                if (r.url.path.endsWith('/orders/order')) {
                  return response(order);
                }
                if (r.url.path.endsWith('/delivery-locations')) {
                  return response([]);
                }
                return response({'cod': true});
              }),
            )
            ..cart = {'items': rows, 'subtotal': 60000}
            ..profile = profile;
      expect(cartCheckoutPayload(store)?['items'], requested);
      await mount(tester, store, const CheckoutScreen());
      await reach(tester, find.text('Kiểm tra giá & tồn kho'));
      await tester.tap(find.text('Kiểm tra giá & tồn kho'));
      await tester.pumpAndSettle();
      await reach(tester, find.text('Xác nhận đặt hàng'));
      await tester.tap(find.text('Xác nhận đặt hàng'));
      await tester.pumpAndSettle();
      expect(removed, [early, later]);
      expect(store.cartItems.map(saleKey), [saleKey(third)]);
      expect(find.byType(OrderScreen), findsOneWidget);
      await reach(tester, find.text('Hạn sử dụng: 01/02/2027'));
      expect(find.text('Hạn sử dụng: 01/03/2027'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
