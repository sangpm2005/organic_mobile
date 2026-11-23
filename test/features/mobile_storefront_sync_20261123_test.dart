import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/data/product_stock_cache.dart';
import 'package:organic_mobile/features/catalog/domain/sale_selection.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_description.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_tile.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_quick_actions.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_suggestions.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/sale_option_picker.dart';
import 'package:organic_mobile/features/home/domain/home_merchandising.dart';
import 'package:organic_mobile/features/orders/domain/delivery_estimate.dart';
import 'package:organic_mobile/features/orders/presentation/widgets/delivery_estimate.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('home includes current lot discounts alongside normal discounts without duplicating products', () async {
    final store = OrganicStore(
      api: OrganicApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/home/discounted-stock')) {
            return response([
              {
                'id': 'p',
                'productName': 'Rau củ',
                'defaultVariantId': 'v',
                'minPrice': 30000,
                'compareAtPrice': 45000,
                'salePromotionId': 'offer',
                'expiryDate': '2027-02-01',
              },
            ]);
          }
          if (r.url.path.endsWith('/home')) {
            return response({
              'discountedProducts': [
                {'id': 'p', 'minPrice': 40000, 'compareAtPrice': 45000},
                {'id': 'other', 'minPrice': 10000, 'compareAtPrice': 20000},
              ],
            });
          }
          return response([]);
        }),
      ),
    );
    await store.loadHome();
    expect(store.discounted.length, 2);
    expect(store.discounted.first.price, 30000);
    expect(store.discounted.first.sale['salePromotionId'], 'offer');
    store.dispose();
  });

  testWidgets(
    'quick add never posts after a price or account change during the fresh stock check',
    (tester) async {
      for (final changeAccount in [false, true]) {
        var reads = 0, posts = 0, opened = 0;
        late OrganicApi api;
        api = OrganicApi(
          client: MockClient((r) async {
            if (r.method == 'POST') {
              posts++;
              return response({});
            }
            reads++;
            if (reads > 1 && changeAccount) {
              api.setSession('another-account', null);
            }
            return response({
              'saleOptions': [
                {
                  'variantId': 'v',
                  'expiryDate': null,
                  'availableQuantity': 3,
                  'price': reads > 1 && !changeAccount ? 50000 : 45000,
                },
              ],
            });
          }),
        );
        final store = OrganicStore(api: api);
        await tester.pumpWidget(
          StoreScope(
            store: store,
            child: MaterialApp(
              home: Scaffold(
                body: ProductQuickActions(
                  Product.fromJson({
                    'id': 'p',
                    'productName': 'Rau củ',
                    'defaultVariantId': 'v',
                    'minPrice': 45000,
                  }),
                  choose: () => opened++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thêm'));
        await tester.pumpAndSettle();
        expect(posts, 0);
        expect(opened, changeAccount ? 0 : 1);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      }
    },
  );

  test('ordinary stock displays its earliest eligible date without sending an explicit expiry to checkout', () {
    final options = [
      {
        'variantId': 'v',
        'expiryDate': '2027-03-01',
        'availableQuantity': 3,
        'price': 45000,
      },
      {
        'variantId': 'v',
        'expiryDate': '2027-02-01',
        'availableQuantity': 2,
        'price': 45000,
      },
      {
        'variantId': 'v',
        'expiryDate': '2027-01-01',
        'availableQuantity': 0,
        'price': 45000,
      },
    ];
    final sale = currentSaleChoice(options)!;
    expect(sale['nearestExpiryDate'], '2027-02-01');
    expect(sale['availableQuantity'], 5);
    expect(saleKey(sale), 'v');
    expect(saleItem({...sale, 'quantity': 4}), {
      'variantId': 'v',
      'quantity': 4,
    });
    expect(
      currentSaleChoice([
        {
          'variantId': 'v',
          'expiryDate': null,
          'nearestExpiryDate': '2027-03-01',
          'availableQuantity': 3,
        },
      ])!['nearestExpiryDate'],
      '2027-03-01',
    );
  });

  test('campaigns switch back to ordinary stock on product discovery while explicit cart identities remain unchanged', () {
    final ordinary = {
      'variantId': 'v',
      'expiryDate': null,
      'nearestExpiryDate': '2027-03-01',
      'availableQuantity': 3,
      'price': 45000,
    };
    final campaign = {
      'variantId': 'v',
      'expiryDate': '2027-02-01',
      'promotionId': 'offer',
      'availableQuantity': 1,
      'price': 30000,
    };
    expect(currentSaleChoice([ordinary, campaign]), campaign);
    expect(
      currentSaleChoice([
        ordinary,
        {...campaign, 'availableQuantity': 0},
      ])!['expiryDate'],
      isNull,
    );
    expect(saleKey({...campaign, 'quantity': 1}), 'v~2027-02-01~offer');
    expect(
      currentSaleChoice([
        {...campaign, 'combo': true},
      ]),
      isNull,
    );
  });

  test('home discovery ranks at most eight real categories and excludes combo categories', () {
    final source = [
      for (var i = 1; i <= 12; i++)
        {'id': '$i', 'name': 'Danh mục $i', 'productCount': i},
      {'id': 'combo', 'name': 'Combo tiết kiệm', 'productCount': 100},
      {'id': 'empty', 'name': 'Trống', 'productCount': 0},
    ];
    final rows = shoppingCategories(source);
    expect(rows.length, 8);
    expect(rows.first['id'], '12');
    expect(rows.last['id'], '5');
    expect(rows.any((r) => r['id'] == 'combo'), isFalse);
  });

  test('delivery countdown interprets Vietnam timestamps, includes hours and never marks an overdue order delivered', () {
    final deadline = deliveryDeadline('2027-02-01T14:00:00')!;
    expect(deadline, DateTime.utc(2027, 2, 1, 7));
    expect(deliveryDeadline('2027-02-01T07:00:00Z'), deadline);
    expect(
      deliveryCountdown(
        deadline,
        deadline.subtract(const Duration(hours: 1, minutes: 2, seconds: 3)),
      ),
      '01:02:03',
    );
    expect(
      deliveryCountdown(deadline, deadline.add(const Duration(seconds: 1))),
      '',
    );
    expect(
      estimatedDeadline({
        'status': 'delivered',
        'estimateStatus': 'estimated',
        'estimatedArrivalAt': '2027-02-01T14:00:00',
      }),
      isNull,
    );
    expect(
      estimatedDeadline({
        'status': 'in_transit',
        'estimateStatus': 'calculating',
        'estimatedArrivalAt': '2027-02-01T14:00:00',
      }),
      isNull,
    );
    expect(deliveryDeadline('invalid'), isNull);
  });

  testWidgets(
    'the detail shows one expiry with the agreed label and preserves description headings',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SaleOfferNotice(
                  selected: {
                    'variantId': 'v',
                    'nearestExpiryDate': '2027-02-01',
                  },
                ),
                ProductDescription(
                  '**1. Giới thiệu sản phẩm**\nRau có lá xanh.\n**2. Bảo quản**\nGiữ mát.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Hạn sử dụng: 01/02/2027'), findsOneWidget);
      expect(find.textContaining('gần nhất'), findsNothing);
      expect(find.byType(Radio<dynamic>), findsNothing);
      expect(find.text('1. Giới thiệu sản phẩm'), findsOneWidget);
      expect(find.text('2. Bảo quản'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tiles use the current discount and hide sold-out stock without showing expiry dates',
    (tester) async {
      var inStock = true;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient(
            (r) async => response({
              'saleOptions': inStock
                  ? [
                      {
                        'variantId': 'v',
                        'expiryDate': '2027-02-01',
                        'promotionId': 'offer',
                        'availableQuantity': 2,
                        'price': 30000,
                        'regularPrice': 45000,
                      },
                    ]
                  : [],
              'availableQuantity': {'v': inStock ? 2 : 0},
            }),
          ),
        ),
      );
      final product = Product.fromJson({
        'id': 'p',
        'productName': 'Rau củ',
        'defaultVariantId': 'v',
        'minPrice': 45000,
        'expiryDate': '2027-02-01',
      });
      Widget tile() => StoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ProductTile(product, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tile());
      await tester.pumpAndSettle();
      expect(find.text('30.000 đ'), findsOneWidget);
      expect(find.textContaining('Hạn sử dụng'), findsNothing);
      inStock = false;
      // Recreate the API cache for this check by expiring the product's cached availability.
      final cache = ProductStockCache.forApi(store.api);
      cache.invalidate('p');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(tile());
      await tester.pumpAndSettle();
      expect(find.text('Rau củ'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'cross-sell uses the existing top-k endpoint and displays only returned products',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/cross-sell')) {
              expect(r.url.queryParameters['k'], '3');
              expect(r.headers.containsKey('authorization'), isFalse);
              return response([
                {'productId': 'other', 'productName': 'Cà rốt'},
              ]);
            }
            return response([]);
          }),
        ),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductSuggestions(productId: 'p', related: []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gợi ý mua kèm'), findsOneWidget);
      expect(find.text('Cà rốt'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'delivery estimate renders, pauses in background and hides after completion',
    (tester) async {
      final deadline = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final shipment = {
        'status': 'in_transit',
        'estimateStatus': 'estimated',
        'estimatedArrivalAt': deadline.toIso8601String(),
        'routeDistanceMeters': 11000,
        'routeDurationSeconds': 1080,
      };
      Widget screen(Map<String, dynamic> s) =>
          MaterialApp(home: Scaffold(body: DeliveryEstimate(s)));
      await tester.pumpWidget(screen(shipment));
      await tester.pump();
      expect(find.byKey(const ValueKey('shipment.countdown')), findsOneWidget);
      expect(find.textContaining('11.0 km'), findsOneWidget);
      expect(find.textContaining('Dữ liệu tuyến đường'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpWidget(screen({...shipment, 'status': 'delivered'}));
      expect(find.byKey(const ValueKey('shipment.countdown')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
