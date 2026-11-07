import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/orders/data/orders_repository.dart';
import 'package:organic_mobile/app/state/organic_store.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  test('automatic sync uses existing payment, then captures approved PayPal through backend', () async {
    final paths = <String>[];
    final api = OrganicApi(
      client: MockClient((r) async {
        paths.add(r.url.path);
        return response({
          'gateway': 'paypal',
          'status': r.url.path.endsWith('capture') ? 'paid' : 'pending',
        });
      }),
    );
    await OrdersRepository(api).reconcile({
      'status': 'pending_payment',
      'paymentStatus': 'pending',
      'paymentMethod': 'paypal',
      'payments': [
        {'id': 'p', 'gateway': 'paypal', 'status': 'pending'},
      ],
    });
    expect(paths.map((p) => p.split('/').last), ['sync', 'capture']);
    expect(paths.any((p) => p.contains('initiate')), isFalse);
    api.close();
  });
  test('paid, COD and attempts requiring review never auto-capture', () async {
    var calls = 0;
    final api = OrganicApi(
      client: MockClient((r) async {
        calls++;
        return response(null);
      }),
    );
    final repository = OrdersRepository(api);
    await repository.reconcile({
      'status': 'confirmed',
      'paymentStatus': 'paid',
      'paymentMethod': 'paypal',
    });
    await repository.reconcile({
      'status': 'pending_payment',
      'paymentStatus': 'pending',
      'paymentMethod': 'cod',
    });
    await repository.reconcile({
      'status': 'pending_payment',
      'paymentStatus': 'pending',
      'paymentMethod': 'paypal',
      'payments': [
        {'id': 'p', 'gateway': 'paypal', 'status': 'requires_review'},
      ],
    });
    expect(calls, 0);
    api.close();
  });
  test('inbox order events suppress duplicate local notifications and discount cards validate prices', () {
    final store = OrganicStore();
    store.orders = [
      {'id': 'order-a', 'status': 'confirmed'},
    ];
    store.inbox = [
      {'id': 'n', 'category': 'order', 'target': '/don-hang/order-a'},
    ];
    expect(store.updates.length, 1);
    store.home = {
      'discountedProducts': [
        {
          'id': '1',
          'name': 'Reduced',
          'minPrice': 9000,
          'compareAtPrice': 10000,
        },
        {
          'id': '2',
          'name': 'Not reduced',
          'minPrice': 10000,
          'compareAtPrice': 10000,
        },
        {
          'id': '1',
          'name': 'Duplicate',
          'minPrice': 9000,
          'compareAtPrice': 10000,
        },
      ],
    };
    expect(store.discounted.map((p) => p.id), ['1']);
    store.dispose();
  });
}
