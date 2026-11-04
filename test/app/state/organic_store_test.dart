import 'package:organic_mobile/core/network/api_exception.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/app/state/organic_store.dart';

http.Response response(dynamic data, [int status = 200]) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
OrganicStore signedIn(http.Client client) {
  final store = OrganicStore(
    api: OrganicApi(baseUrl: 'http://localhost/api/v1', client: client),
  );
  store.api.setSession('access-a', 'refresh-a');
  store.user = {'accountId': 'a'};
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'catalog categories load independently from a failed home request',
    () async {
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((r) async {
            expect(r.headers['Authorization'], isNull);
            expect(r.url.path, '/api/v1/categories');
            return response({
              'items': [
                {'id': 'vegetable', 'categoryName': 'Rau củ'},
              ],
            });
          }),
        ),
      );
      await store.loadCategories();
      expect(store.home, isEmpty);
      expect(store.categories.single['name'], 'Rau củ');
      store.dispose();
    },
  );
  test(
    'refresh after mutation waits for an old poll and fetches again',
    () async {
      final started = Completer<void>(), oldCart = Completer<http.Response>();
      var reads = 0;
      final store = signedIn(
        MockClient((r) async {
          if (r.url.path.endsWith('/cart')) {
            reads++;
            if (reads == 1) {
              started.complete();
              return oldCart.future;
            }
            return response({'totalQuantity': 2, 'items': []});
          }
          return response([]);
        }),
      );
      final poll = store.refreshAccount();
      await started.future;
      final after = store.refreshAccount(force: true);
      oldCart.complete(response({'totalQuantity': 1, 'items': []}));
      await Future.wait([poll, after]);
      expect(reads, 2);
      expect(store.cartCount, 2);
      store.dispose();
    },
  );
  test(
    'one failed account module does not discard successful modules',
    () async {
      final store = signedIn(
        MockClient((r) async {
          if (r.url.path.endsWith('/customers/me')) return response({}, 503);
          if (r.url.path.endsWith('/cart')) {
            return response({'totalQuantity': 3, 'items': []});
          }
          if (r.url.path.endsWith('/rewards')) {
            return response({'available': 2});
          }
          return response([]);
        }),
      );
      await store.refreshAccount();
      expect(store.cartCount, 3);
      expect(store.rewards?['available'], 2);
      expect(store.accountError, isNotNull);
      store.dispose();
    },
  );
  test('old cart poll cannot overwrite a newer cart mutation', () async {
    final polled = Completer<void>(), oldCart = Completer<http.Response>();
    final store = signedIn(
      MockClient((r) async {
        if (r.url.path.endsWith('/cart')) {
          polled.complete();
          return oldCart.future;
        }
        if (r.url.path.endsWith('/cart/items')) {
          return response({'totalQuantity': 2, 'items': []});
        }
        return response([]);
      }),
    );
    final refresh = store.refreshAccount();
    await polled.future;
    await store.add('variant', 2);
    oldCart.complete(response({'totalQuantity': 1, 'items': []}));
    await refresh;
    expect(store.cartCount, 2);
    store.dispose();
  });
  test('late private mutation cannot restore cart after logout', () async {
    final started = Completer<void>(), late = Completer<http.Response>();
    final store = signedIn(
      MockClient((r) async {
        if (r.url.path.endsWith('/cart/items')) {
          started.complete();
          return late.future;
        }
        return response({});
      }),
    );
    final pending = expectLater(
      store.add('variant', 1),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await store.logout();
    late.complete(
      response({
        'totalQuantity': 1,
        'items': [
          {'variantId': 'private'},
        ],
      }),
    );
    await pending;
    expect(store.loggedIn, false);
    expect(store.cart, isNull);
    store.dispose();
  });
  test(
    'uncertain checkout survives restart and is cleared with account logout',
    () async {
      final store = signedIn(MockClient((_) async => response({})));
      await store.savePendingCheckout({
        'key': 'same-order',
        'payload': {'points': 0},
      });
      final restored = OrganicStore(
        api: OrganicApi(client: MockClient((_) async => response([]))),
      );
      await restored.initialize();
      expect(restored.pendingCheckout?['key'], 'same-order');
      await restored.logout();
      restored.dispose();
      final loggedOut = OrganicStore();
      await loggedOut.initialize();
      expect(loggedOut.pendingCheckout, isNull);
      expect(loggedOut.loggedIn, false);
      loggedOut.dispose();
      store.dispose();
    },
  );
}
