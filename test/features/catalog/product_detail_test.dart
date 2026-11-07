import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/features/catalog/domain/product.dart';
import 'package:organic_mobile/features/catalog/domain/product_detail.dart';

void main() {
  test('sizes stay in one parent product and only active priced sizes are selectable', () {
    final data = {
      'id': 'juice',
      'variants': [
        {
          'id': 'large',
          'variantName': 'Chai',
          'netQuantity': 946,
          'unitId': 'ml',
          'sellingPrice': 180000,
          'status': 'active',
        },
        {
          'id': 'small',
          'variantName': 'Chai',
          'netQuantity': 250,
          'unitId': 'ml',
          'sellingPrice': 60000,
          'status': 'active',
        },
        {
          'id': 'retired',
          'netQuantity': 500,
          'sellingPrice': 90000,
          'status': 'inactive',
        },
        {
          'id': 'unpriced',
          'netQuantity': 500,
          'sellingPrice': 0,
          'status': 'active',
        },
      ],
    };
    expect(
      ProductPage.fromJson({
        'items': [data],
      }).items.single.id,
      'juice',
    );
    final variants = sellableVariants(data);
    expect(variants.map((v) => v['id']), ['small', 'large']);
    expect(variantDisplayName(variants.first), 'Chai · 250 ml');
    expect(variantDisplayName(variants.last), 'Chai · 946 ml');
    expect(
      variantDisplayName({
        'variantName': 'Gói 500 g',
        'netQuantity': 500,
        'unitId': 'g',
      }),
      'Gói 500 g',
    );
    expect(
      variantDisplayName({
        'variantName': 'Túi',
        'netQuantity': 1.5,
        'unitId': 'kg',
      }),
      'Túi · 1,5 kg',
    );
  });

  test('gallery keeps all distinct photos, primary first, ordered and with accessible descriptions', () {
    final photos = productImages({
      'productName': 'Nước ép táo',
      'images': [
        {'imageUrl': 'https://cdn.example/side.jpg', 'sortOrder': 2},
        {'imageUrl': 'https://cdn.example/back.jpg', 'sortOrder': 1},
        {
          'imageUrl': 'https://cdn.example/front.jpg',
          'isPrimary': true,
          'sortOrder': 9,
          'altText': 'Mặt trước chai',
        },
        {'imageUrl': 'https://cdn.example/front.jpg'},
        {'imageUrl': 'javascript:alert(1)'},
        {'imageUrl': 'https://user:pass@cdn.example/private.jpg'},
      ],
    });
    expect(photos.map((p) => p.url), [
      'https://cdn.example/front.jpg',
      'https://cdn.example/back.jpg',
      'https://cdn.example/side.jpg',
    ]);
    expect(photos.first.alt, 'Mặt trước chai');
    expect(photos[1].alt, contains('Nước ép táo'));
    expect(
      productImages({
        'imageUrl': '/media/apple.jpg',
      }, baseUrl: 'http://localhost:8088/api/v1').single.url,
      'http://localhost:8088/media/apple.jpg',
    );
    expect(productImages({}), isEmpty);
  });
}
