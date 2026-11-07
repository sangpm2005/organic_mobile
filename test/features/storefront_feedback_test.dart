import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/auth/presentation/login_screen.dart';
import 'package:organic_mobile/features/cart/presentation/cart_screen.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/product_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_grid.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_tile.dart';
import 'package:organic_mobile/features/home/presentation/home_screen.dart';
import 'package:organic_mobile/features/home/presentation/widgets/home_banners.dart';
import 'package:organic_mobile/features/store_info/presentation/contact_screen.dart';
import 'package:organic_mobile/features/store_info/presentation/store_info_screen.dart';
import 'package:organic_mobile/features/store_info/domain/store_contact.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../helpers/customer_fixtures.dart';

const productName =
    'Bí ngòi xanh hữu cơ thu hoạch tại nông trại Đà Lạt – gói dành cho cả gia đình';
Map<String, dynamic> card(String id) => {
  'id': id,
  'name': '$productName $id',
  'categoryName': 'Rau củ và trái cây hữu cơ đạt chứng nhận',
  'defaultVariantName': 'Gói bảo quản tươi 500 g',
  'defaultPrice': 45000,
};

Future<void> mount(
  WidgetTester tester,
  OrganicStore store,
  Widget page, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
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
        home: Scaffold(body: page),
      ),
    ),
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
      'Lora',
    )..addFont(rootBundle.load('assets/fonts/Lora.ttf'))).load();
  });

  test('footer defaults fill only missing contact fields and keep published API values', () {
    expect(
      StoreContact.withDefaults({
        'contactPhone': '  ',
        'contactEmail': null,
      })['contactPhone'],
      '028 7307 1088',
    );
    final updated = StoreContact.withDefaults({
      'contactPhone': '0901234567',
      'contactEmail': 'service@organicfood.vn',
    });
    expect(updated['contactPhone'], '0901234567');
    expect(updated['contactEmail'], 'service@organicfood.vn');
  });

  testWidgets('contact remains available from footer when the API is offline', (
    tester,
  ) async {
    final store = OrganicStore(
      api: OrganicApi(client: MockClient((r) async => response({}, 503))),
    );
    await mount(tester, store, const ContactScreen());
    expect(find.text('028 7307 1088'), findsOneWidget);
    expect(find.text('info@organicfood.vn'), findsOneWidget);
    expect(
      find.textContaining('Đang hiển thị thông tin liên hệ từ footer'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'catalog replaces each page with at most eight products and resets when searching',
    (tester) async {
      final requested = <(int, int)>[];
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/categories')) return response([]);
            final page = int.parse(r.url.queryParameters['page']!);
            final size = int.parse(r.url.queryParameters['size']!);
            requested.add((page, size));
            return response({
              'items': List.generate(
                page == 0 ? 8 : 2,
                (i) => card('${page * 8 + i}'),
              ),
              'totalElements': 10,
              'totalPages': 2,
            });
          }),
        ),
      );
      await mount(tester, store, const CatalogScreen(embedded: true));
      expect(find.byType(ProductTile), findsNWidgets(8));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('catalog.next')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('catalog.next')));
      await tester.pumpAndSettle();
      expect(find.byType(ProductTile), findsNWidgets(2));
      expect(find.byKey(const ValueKey('product.tile.0')), findsNothing);
      expect(find.byKey(const ValueKey('product.tile.8')), findsOneWidget);
      expect(requested, [(0, 8), (1, 8)]);
      await tester.enterText(
        find.byKey(const ValueKey('catalog.search')),
        'rau',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(requested.last, (0, 8));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'full product names and review controls fit ${width}px at ${scale}x text',
        (tester) async {
          final store = OrganicStore(
            api: OrganicApi(
              client: MockClient((r) async {
                if (r.url.path.endsWith('/reviews')) {
                  return response({
                    'reviews': {
                      'items': [
                        {
                          'reviewerName': 'Khách hàng',
                          'rating': 5,
                          'title': productName,
                          'content': 'Sản phẩm tươi ngon, đóng gói cẩn thận.',
                        },
                      ],
                      'totalElements': 1,
                    },
                  });
                }
                if (r.url.path.endsWith('/availability')) {
                  return response({
                    'availableQuantity': {'v': 10},
                  });
                }
                return response({
                  'id': 'p',
                  'productName': productName,
                  'categoryName': 'Rau củ',
                  'variants': [
                    {
                      'id': 'v',
                      'variantName': 'Gói bảo quản tươi 500 g dành cho cả nhà',
                      'sellingPrice': 45000,
                      'netQuantity': 500,
                      'unitId': 'g',
                      'status': 'active',
                    },
                  ],
                  'description': 'Nguồn gốc được công bố rõ ràng. Bảo quản nơi thoáng mát.',
                  'reviewSummary': {'totalReviews': 1, 'averageRating': 5},
                });
              }),
            ),
          );
          await mount(
            tester,
            store,
            ListView(
              children: [
                ProductGrid([
                  Product.fromJson(card('p')),
                  Product.fromJson(card('q')),
                ], onTap: (_) {}),
              ],
            ),
            width: width,
            scale: scale,
          );
          final title = tester.widget<Text>(find.text('$productName p'));
          expect(title.maxLines, isNull);
          expect(title.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.takeException(), isNull);
          await mount(
            tester,
            store,
            const ProductScreen('p'),
            width: width,
            scale: scale,
          );
          await tester.scrollUntilVisible(
            find.text('Lọc theo số sao'),
            350,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final summary = tester.getRect(find.text('1 đánh giá · 5 / 5'));
          final filter = tester.getRect(
            find.byType(DropdownButtonFormField<int>),
          );
          expect(summary.bottom, lessThan(filter.top));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          store.dispose();
        },
      );
    }
  }

  testWidgets(
    'guest adds from product detail and checkout requires login without losing cart',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/cart/items')) {
              return response({
                'totalQuantity': 1,
                'subtotal': 45000,
                'items': [
                  {
                    'variantId': 'v',
                    'productName': productName,
                    'variantName': 'Gói 500g',
                    'quantity': 1,
                    'unitPrice': 45000,
                    'lineTotal': 45000,
                    'available': true,
                  },
                ],
              });
            }
            if (r.url.path.endsWith('/reviews')) {
              return response({
                'reviews': {'items': []},
              });
            }
            if (r.url.path.endsWith('/availability')) {
              return response({
                'availableQuantity': {'v': 10},
              });
            }
            return response({
              'id': 'p',
              'productName': productName,
              'variants': [
                {
                  'id': 'v',
                  'variantName': 'Gói 500g',
                  'sellingPrice': 45000,
                  'netQuantity': 500,
                  'unitId': 'g',
                  'status': 'active',
                },
              ],
            });
          }),
        ),
      );
      await mount(tester, store, const ProductScreen('p'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('product.add')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('product.add')));
      await tester.pumpAndSettle();
      expect(store.cartCount, 1);
      expect(find.byType(LoginScreen), findsNothing);
      await mount(tester, store, const CartScreen());
      await tester.scrollUntilVisible(
        find.text('Tiến hành đặt hàng'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tiến hành đặt hàng'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(store.cartCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'home combines distinct recommendation groups, shows offers and puts explore after products',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient(
            (r) async => response(
              r.url.path.endsWith('/home')
                  ? {
                      'featuredProducts': [card('0')],
                      'newProducts': List.generate(8, (i) => card('$i')),
                      'certifiedProducts': [card('0')],
                      'content': {},
                      'categories': [],
                    }
                  : {
                      'offers': [
                        {
                          'id': 'offer',
                          'name': 'Ưu đãi rau xanh cuối tuần',
                          'discountType': 'percentage',
                          'discountValue': 10,
                          'description':
                              'Áp dụng cho rau xanh trong chương trình.',
                        },
                      ],
                    },
            ),
          ),
        ),
      );
      await mount(tester, store, HomeScreen(catalog: () {}));
      expect(store.featured.length, 8);
      final grid = tester.widget<ProductGrid>(find.byType(ProductGrid));
      expect(grid.products.map((p) => p.id).toSet().length, 8);
      final children =
          (tester.widget<ListView>(find.byType(ListView).first).childrenDelegate
                  as SliverChildListDelegate)
              .children;
      expect(
        ((children.last as Padding).child as FilledButton).key,
        const ValueKey('home.explore'),
      );
      await tester.scrollUntilVisible(
        find.byType(HomeBanners),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ưu đãi rau xanh cuối tuần'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home.explore')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('home.explore')), findsOneWidget);
      expect(find.text('Khám phá sản phẩm'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'about links open source records, certificate records, variants and public contact page',
    (tester) async {
      final paths = <String>[];
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            paths.add(r.url.path);
            if (r.url.path.endsWith('/content')) {
              return response({
                'introduction': 'Thông tin cửa hàng',
                'highlights': [
                  {
                    'title': 'Thông tin nguồn gốc',
                    'description': 'Vùng sản xuất',
                  },
                  {
                    'title': 'Kiểm tra chứng nhận',
                    'description': 'Tổ chức cấp',
                  },
                  {
                    'title': 'Lựa chọn quy cách',
                    'description': 'Chọn sản phẩm',
                  },
                ],
                'contactPhone': null,
                'contactEmail': null,
              });
            }
            if (r.url.path.endsWith('/origins')) {
              return response([
                {'id': 'o', 'name': 'Nông trại Đà Lạt', 'country': 'Việt Nam'},
              ]);
            }
            if (r.url.path.endsWith('/certifications')) {
              return response([
                {
                  'id': 'c',
                  'name': 'Chứng nhận canh tác',
                  'issuingOrganization': 'Tổ chức cấp',
                },
              ]);
            }
            return response({'items': [], 'totalElements': 0, 'totalPages': 0});
          }),
        ),
      );
      await mount(tester, store, const StoreInfoScreen());
      for (final title in [
        'Thông tin nguồn gốc',
        'Kiểm tra chứng nhận',
        'Lựa chọn quy cách',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(
        paths,
        containsAll([
          '/api/v1/home/origins',
          '/api/v1/home/certifications',
          '/api/v1/products',
        ]),
      );
      await tester.ensureVisible(find.text('Thông tin liên hệ'));
      await tester.tap(find.text('Thông tin liên hệ'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactScreen), findsOneWidget);
      expect(find.text('028 7307 1088'), findsOneWidget);
      expect(find.text('info@organicfood.vn'), findsOneWidget);
      expect(
        find.text('123 Đinh Tiên Hoàng, Quận 1, Thành phố Hồ Chí Minh'),
        findsOneWidget,
      );
      expect(find.text('7h – 20h · Thứ Hai đến Chủ Nhật'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
