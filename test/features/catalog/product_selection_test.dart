import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/catalog/domain/product_detail.dart';
import 'package:organic_mobile/features/catalog/presentation/product_screen.dart';
import 'package:organic_mobile/features/cart/presentation/cart_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_gallery.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'size selection changes price, stock and the variant sent to guest cart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? added;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/cart/items')) {
              added = jsonDecode(r.body);
              return response({
                'totalQuantity': 1,
                'subtotal': 180000,
                'items': [
                  {
                    'variantId': added?['variantId'],
                    'quantity': added?['quantity'],
                    'productName': 'Nước ép táo',
                    'variantName': 'Chai',
                    'netQuantity': 946,
                    'unitId': 'ml',
                    'unitPrice': 180000,
                    'lineTotal': 180000,
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
                'availableQuantity': {'small': 5, 'large': 1, 'sold': 0},
              });
            }
            return response({
              'id': 'juice',
              'productName': 'Nước ép táo',
              'defaultVariantId': 'small',
              'variants': [
                {
                  'id': 'small',
                  'variantName': 'Chai',
                  'netQuantity': 250,
                  'unitId': 'ml',
                  'sellingPrice': 60000,
                  'status': 'active',
                },
                {
                  'id': 'large',
                  'variantName': 'Chai',
                  'netQuantity': 946,
                  'unitId': 'ml',
                  'sellingPrice': 180000,
                  'status': 'active',
                },
                {
                  'id': 'sold',
                  'variantName': 'Thùng',
                  'netQuantity': 6,
                  'unitId': 'l',
                  'sellingPrice': 900000,
                  'status': 'active',
                },
                {
                  'id': 'retired',
                  'variantName': 'Không bán',
                  'netQuantity': 500,
                  'unitId': 'ml',
                  'sellingPrice': 100000,
                  'status': 'inactive',
                },
              ],
            });
          }),
        ),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: organicTheme(),
            home: const ProductScreen('juice'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('product.variant.large')),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Chai · 250 ml'), findsOneWidget);
      expect(find.text('Chai · 946 ml'), findsOneWidget);
      expect(find.text('Không bán'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('product.price'))).data,
        '60.000 đ',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('product.increase')),
      );
      await tester.tap(find.byKey(const ValueKey('product.increase')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('product.variant.large')),
      );
      await tester.tap(find.byKey(const ValueKey('product.variant.large')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('product.price')),
        -150,
        scrollable: scrollable,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('product.price'))).data,
        '180.000 đ',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('product.stock'))).data,
        contains('1 sản phẩm'),
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('product.increase')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('product.add')));
      await tester.tap(find.byKey(const ValueKey('product.add')));
      await tester.pumpAndSettle();
      expect(added, {'variantId': 'large', 'quantity': 1});
      await tester.ensureVisible(
        find.byKey(const ValueKey('product.variant.sold')),
      );
      await tester.tap(find.byKey(const ValueKey('product.variant.sold')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('product.add')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: organicTheme(),
            home: const Scaffold(body: CartScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chai · 946 ml'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'gallery swipes and thumbnails select every angle and opens a zoomable viewer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ProductGallery(
                  List.generate(
                    3,
                    (i) => ProductImage('https://cdn.example/$i.jpg', 'Góc $i'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh 1/3'), findsOneWidget);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .every((i) => i.fit == BoxFit.contain),
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('product.gallery.thumbnail.2')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh 3/3'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('product.gallery.pages')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh 2/3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('product.gallery.expand')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsWidgets);
      expect(find.text('Ảnh 2/3'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('product.gallery.viewer')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh 3/3'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
