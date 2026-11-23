import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/catalog/domain/sale_selection.dart';
import 'package:organic_mobile/features/checkout/data/checkout_repository.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  test('selection identity distinguishes dates and offers while retaining legacy cart keys', () {
    expect(saleKey({'variantId': 'v'}), 'v');
    expect(
      saleKey({'variantId': 'v', 'expiryDate': '2027-02-01'}),
      'v~2027-02-01~',
    );
    final option = {
      'variantId': 'v',
      'expiryDate': '2027-02-01',
      'promotionId': 'offer',
    };
    expect(saleKey(option), 'v~2027-02-01~offer');
    expect(saleItem({...option, 'quantity': 2, 'price': 10000}), {
      'variantId': 'v',
      'quantity': 2,
      'expiryDate': '2027-02-01',
      'salePromotionId': 'offer',
    });
    expect(saleItem({'variantId': 'v', 'quantity': 2}), {
      'variantId': 'v',
      'quantity': 2,
    });
  });
  test('availability choices are scoped by variant; disappeared selection does not silently switch', () {
    final availability = {
      'saleOptions': [
        {'variantId': 'v', 'expiryDate': '2027-02-01', 'availableQuantity': 2},
        {'variantId': 'v', 'expiryDate': '2027-02-02', 'availableQuantity': 0},
        {
          'variantId': 'other',
          'expiryDate': '2027-02-01',
          'availableQuantity': 9,
        },
      ],
    };
    final options = saleChoices(availability, 'v');
    expect(options.length, 1);
    expect(selectedSale(options, 'v~2027-02-02~'), isNull);
    expect(supportsSaleChoices({'saleOptions': []}), isTrue);
    expect(
      supportsSaleChoices({
        'availableQuantity': {'v': 5},
      }),
      isFalse,
    );
    expect(saleDate('2027-02-01'), '01/02/2027');
  });
  test('preview refuses a server quote that drops or changes the requested expiry choice', () async {
    final requested = {
      'variantId': 'v',
      'quantity': 1,
      'expiryDate': '2027-02-01',
      'salePromotionId': 'offer',
    };
    for (final line in [
      {'variantId': 'v', 'quantity': 1},
      {...requested, 'expiryDate': '2027-02-02'},
      {...requested, 'salePromotionId': 'other'},
      {...requested, 'quantity': 2},
    ]) {
      final api = OrganicApi(
        client: MockClient(
          (_) async => response({
            'items': [line],
          }),
        ),
      );
      await expectLater(
        CheckoutRepository(api).preview({
          'items': [requested],
        }),
        throwsA(isA<ApiException>()),
      );
      api.client.close();
    }
    final api = OrganicApi(
      client: MockClient(
        (_) async => response({
          'items': [requested],
        }),
      ),
    );
    expect(
      (await CheckoutRepository(api).preview({
        'items': [requested],
      }))['items'],
      [requested],
    );
    api.client.close();
  });
}
