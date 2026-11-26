import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/home/domain/home_merchandising.dart';
import 'package:organic_mobile/features/home/presentation/widgets/home_collections.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_grid.dart';
import 'package:organic_mobile/features/promotions/domain/combo_pricing.dart';
import 'package:organic_mobile/features/promotions/presentation/widgets/promotion_products.dart';
import 'package:organic_mobile/features/promotions/presentation/widgets/promotion_carousel.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_photo.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/offer_carousel.dart';

import '../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Widget carousel({
    ValueChanged<int>? onOpen,
    Widget? first,
    List<String> ids = const ['a', 'b'],
  }) => MaterialApp(
    home: Scaffold(
      body: OfferCarousel(
        slideIds: ids,
        onOpen: onOpen,
        slides: [
          for (final id in ids)
            SizedBox(
              width: 300,
              height: 180,
              child: id == ids.first && first != null
                  ? first
                  : OfferCarouselTapArea(child: Text('Slide $id')),
            ),
        ],
      ),
    ),
  );

  testWidgets('carousel advances at four seconds and respects reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(carousel(onOpen: (_) {}));
    await tester.pump(const Duration(milliseconds: 3999));
    expect(find.text('Slide a'), findsOneWidget);
    expect(find.text('Slide b'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Slide b'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: OfferCarousel(slides: const [Text('Still'), Text('Next')]),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Still'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'single tap advances; double tap opens the current slide without advancing',
    (tester) async {
      final opened = <int>[];
      await tester.pumpWidget(carousel(onOpen: opened.add));
      await tester.tap(find.text('Slide a'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Slide b'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(find.text('Slide b'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Slide b'));
      await tester.pumpAndSettle();
      expect(opened, [1]);
      expect(find.text('Slide b'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'transition between different banner heights does not squeeze outgoing content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfferCarousel(
                slides: [
                  Column(
                    children: const [
                      Text('Tall banner'),
                      SizedBox(height: 300),
                    ],
                  ),
                  const Text('Short banner'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Short banner'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'interactive children keep their action and a swipe advances once',
    (tester) async {
      var clicks = 0;
      final opened = <int>[];
      await tester.pumpWidget(
        carousel(
          onOpen: opened.add,
          first: TextButton(
            onPressed: () => clicks++,
            child: const Text('Details'),
          ),
        ),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(clicks, 1);
      expect(opened, isEmpty);
      expect(find.text('Details'), findsOneWidget);
      await tester.fling(
        find.byType(OfferCarousel),
        const Offset(-220, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Slide b'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'carousel keeps offer identity when feeds reorder and pauses in background',
    (tester) async {
      await tester.pumpWidget(carousel(onOpen: (_) {}));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(carousel(onOpen: (_) {}, ids: ['b', 'a']));
      expect(find.text('Slide b'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Slide b'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Slide a'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('category image fallback uses shelves, then its own category; failure preserves discovery', () async {
    final requested = <String>[];
    final rows = await homeCategoryImages(
      {
        'categories': [
          {'id': 'drink', 'name': 'Đồ uống', 'productCount': 3},
          {'id': 'veg', 'name': 'Rau củ', 'productCount': 2},
          {'id': 'rice', 'name': 'Gạo', 'productCount': 1},
          {'id': 'combo', 'name': 'Combo rau', 'productCount': 9},
        ],
        'featuredProducts': [
          {
            'id': 'p',
            'categoryId': 'veg',
            'imageUrl': 'https://example.com/veg.png',
          },
        ],
      },
      (id) async {
        requested.add(id);
        if (id == 'rice') {
          throw Exception('offline');
        }
        return [
          {'imageUrl': 'https://example.com/drink.png'},
        ];
      },
    );
    expect(rows.map((c) => c['id']), ['drink', 'veg', 'rice']);
    expect(rows[0]['imageUrl'], 'https://example.com/drink.png');
    expect(rows[1]['imageUrl'], 'https://example.com/veg.png');
    expect(rows[2]['imageUrl'], isNull);
    expect(requested, ['drink', 'rice']);
  });

  test('home requests a missing category photo without descendants', () async {
    final queries = <Map<String, String>>[];
    final store = OrganicStore(
      api: OrganicApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/products')) {
            queries.add(r.url.queryParameters);
            return response({
              'items': [
                {'imageUrl': 'https://example.com/tea.png'},
              ],
            });
          }
          if (r.url.path.endsWith('/home')) {
            return response({
              'categories': [
                {'id': 'tea', 'name': 'Trà', 'productCount': 1},
              ],
            });
          }
          return response([]);
        }),
      ),
    );
    await store.loadHome();
    expect(queries.single['categoryId'], 'tea');
    expect(queries.single['includeDescendants'], 'false');
    expect(
      objects(store.home['categories']).single['imageUrl'],
      'https://example.com/tea.png',
    );
    store.dispose();
  });

  test('late home responses cannot replace a newer catalog snapshot', () async {
    final first = Completer<void>();
    var homes = 0;
    final store = OrganicStore(
      api: OrganicApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/home')) {
            final request = ++homes;
            if (request == 1) await first.future;
            return response({'revision': request});
          }
          return response([]);
        }),
      ),
    );
    final older = store.loadHome();
    await Future<void>.delayed(Duration.zero);
    await store.loadHome();
    first.complete();
    await older;
    expect(store.home['revision'], 2);
    store.dispose();
  });

  Json variant(double price, [String id = 'small']) => {
    'id': id,
    'price': price,
    'variantName': id,
    'availableQuantity': 20,
  };
  Json offer({
    String type = 'percentage',
    double discount = 10,
    double? cap,
    double minimum = 0,
  }) => {
    'promotionType': 'combo',
    'discountType': type,
    'discountValue': discount,
    'minOrderValue': minimum,
    'maxDiscountAmount': ?cap,
    'products': [
      {
        'productId': 'p',
        'productName': 'Trà xanh',
        'requiredQuantity': 2,
        'variants': [variant(30000), variant(50000, 'large')],
      },
    ],
  };

  test(
    'combo estimate respects selected quantity, minimum, cap and subtotal',
    () {
      expect(comboEstimate(offer(), initialComboVariant), (
        subtotal: 60000.0,
        discount: 6000.0,
        total: 54000.0,
      ));
      expect(
        comboEstimate(offer(cap: 3000), initialComboVariant)!.total,
        57000,
      );
      expect(
        comboEstimate(offer(minimum: 100000), initialComboVariant)!.discount,
        0,
      );
      expect(
        comboEstimate(
          offer(type: 'fixed', discount: 90000),
          initialComboVariant,
        )!.total,
        0,
      );
      expect(comboEstimate(offer(), (_) => null), isNull);
    },
  );

  testWidgets(
    'changing combo variant recalculates the estimate before adding',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(client: MockClient((_) async => response({}))),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PromotionProducts(offer: offer()),
              ),
            ),
          ),
        ),
      );
      expect(find.text('54.000 đ'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('large').last);
      await tester.pumpAndSettle();
      expect(find.text('90.000 đ'), findsOneWidget);
      expect(find.text('54.000 đ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'combo preview fits a narrow phone, opens its details and pauses while the details are open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = OrganicStore(
        api: OrganicApi(client: MockClient((_) async => response({}))),
      );
      final first = {
        ...offer(),
        'id': 'a',
        'name': 'Combo trà xanh cho bữa sáng',
      };
      final second = {...offer(), 'id': 'b', 'name': 'Combo thứ hai'};
      first['products'] = [
        {
          ...objects(first['products']).first,
          'imageUrl': 'https://example.com/tea.png',
          'productName': 'Trà xanh hữu cơ hương nhài túi lọc',
        },
      ];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PromotionCarousel(offers: [first, second]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProductPhoto>(find.byType(ProductPhoto)).url,
        'https://example.com/tea.png',
      );
      await tester.tap(find.text('Combo trà xanh cho bữa sáng'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Combo trà xanh cho bữa sáng'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết ưu đãi'), findsOneWidget);
      expect(find.text('Combo trà xanh cho bữa sáng'), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Combo trà xanh cho bữa sáng'), findsOneWidget);
      expect(find.text('Combo thứ hai'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'home collection and category filters display the corresponding source products',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(client: MockClient((_) async => response({}))),
      );
      Json p(String id, String category) => {
        'id': id,
        'productName': id,
        'categoryId': category,
        'minPrice': 10000,
      };
      final home = {
        'featuredProducts': [p('Tea', 'drink')],
        'newProducts': [p('Rice', 'rice')],
        'certifiedProducts': [p('Certified tea', 'drink')],
        'categories': [
          {'id': 'drink', 'name': 'Đồ uống'},
          {'id': 'rice', 'name': 'Gạo'},
        ],
      };
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeCollections(home: home)),
            ),
          ),
        ),
      );
      ProductGrid grid() =>
          tester.widget<ProductGrid>(find.byType(ProductGrid));
      expect(grid().products.map((p) => p.id), [
        'Tea',
        'Rice',
        'Certified tea',
      ]);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gạo').last);
      await tester.pumpAndSettle();
      expect(grid().products.single.id, 'Rice');
      await tester.ensureVisible(
        find.byKey(const ValueKey('home.group.certified')),
      );
      await tester.tap(find.byKey(const ValueKey('home.group.certified')));
      await tester.pumpAndSettle();
      expect(grid().products.single.id, 'Certified tea');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
