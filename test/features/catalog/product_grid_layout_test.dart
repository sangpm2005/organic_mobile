import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_grid.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('BeVietnamPro')
          ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final products = [
    {
      'id': 'p1',
      'productName': 'Hủ tiếu bột lọc hữu cơ Bích Chi',
      'categoryName': 'Bún, phở và hủ tiếu',
      'unit': 'Gói',
      'minPrice': 37000,
      'compareAtPrice': 45000,
    },
    {
      'id': 'p2',
      'productName': 'Dứa mật MD2',
      'categoryName': 'Trái cây',
      'unit': 'Túi',
      'minPrice': 58500,
    },
    {
      'id': 'p3',
      'productName': 'Bún gạo lứt hữu cơ Bích Chi',
      'categoryName': 'Bún, phở và hủ tiếu',
      'unit': 'Gói',
      'minPrice': 48000,
    },
    {
      'id': 'p4',
      'productName': 'Bơ sáp 034',
      'categoryName': 'Trái cây',
      'unit': 'Túi',
      'minPrice': 85500,
      'compareAtPrice': 100000,
    },
  ].map((p) => Product.fromJson({...p, 'defaultVariantId': p['id']})).toList();

  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'cards and purchase controls align at $width px / $scale text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = OrganicStore(
            api: OrganicApi(
              client: MockClient(
                (r) async => response({
                  'availableQuantity': {for (final p in products) p.id: 8},
                }),
              ),
            ),
          );
          final capture = GlobalKey();
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
                home: Scaffold(
                  appBar: AppBar(title: const Text('Sản phẩm')),
                  body: RepaintBoundary(
                    key: capture,
                    child: SingleChildScrollView(
                      child: ProductGrid(products, onTap: (_) {}),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final rects = [
            for (final p in products)
              tester.getRect(find.byKey(ValueKey('product.tile.${p.id}'))),
          ];
          for (final rect in rects) {
            expect(rect.height, closeTo(rects.first.height, 0.1));
          }
          final columns = width < 350 || 12 * scale > 18
              ? 1
              : width > 650
              ? 3
              : 2;
          for (var i = 0; i < products.length; i++) {
            final tile = find.byKey(ValueKey('product.tile.${products[i].id}'));
            final title = tester.widget<Text>(find.text(products[i].name));
            expect(title.maxLines, isNull);
            expect(title.overflow, isNot(TextOverflow.ellipsis));
            final button = find.descendant(
              of: tile,
              matching: find.widgetWithText(TextButton, 'Thêm'),
            );
            final previous = find.byKey(
              ValueKey('product.tile.${products[i - i % columns].id}'),
            );
            final previousButton = find.descendant(
              of: previous,
              matching: find.widgetWithText(TextButton, 'Thêm'),
            );
            expect(
              tester.getRect(button).top,
              closeTo(tester.getRect(previousButton).top, 0.1),
            );
            final price = find.descendant(
              of: tile,
              matching: find.text(money(products[i].price)),
            );
            final previousPrice = find.descendant(
              of: previous,
              matching: find.text(money(products[i - i % columns].price)),
            );
            expect(
              tester.getRect(price).top,
              closeTo(tester.getRect(previousPrice).top, 0.1),
            );
          }
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                '.local/verification/product-grid-aligned.png',
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          store.dispose();
        },
      );
    }
  }
}
