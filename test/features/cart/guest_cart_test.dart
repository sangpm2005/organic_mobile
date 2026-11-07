import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('guest cart survives restart, merges once on login and account cart survives relogin', () async {
    final cookie = 'g' * 43;
    var guestQuantity = 0, customerQuantity = 2, merges = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/auth/login')) {
        return response({
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {
            'accountId': 'a',
            'roles': ['CUSTOMER'],
          },
        });
      }
      if (r.url.path.contains('/cart')) {
        final signedIn = r.headers['Authorization'] != null;
        if (r.method == 'POST') {
          expect(signedIn, false);
          guestQuantity += (jsonDecode(r.body)['quantity'] as num).toInt();
        }
        if (r.method == 'GET' && signedIn && r.headers['Cookie'] != null) {
          expect(r.headers['Cookie'], 'organic_cart=$cookie');
          customerQuantity += guestQuantity;
          guestQuantity = 0;
          merges++;
        }
        if (!signedIn && r.method == 'GET') {
          expect(r.headers['Cookie'], 'organic_cart=$cookie');
        }
        final result = response({
          'totalQuantity': signedIn ? customerQuantity : guestQuantity,
          'items': [
            {
              'variantId': 'v',
              'available': true,
              'quantity': signedIn ? customerQuantity : guestQuantity,
            },
          ],
        });
        return http.Response.bytes(
          result.bodyBytes,
          200,
          headers: {
            ...result.headers,
            if (r.method == 'POST')
              'set-cookie':
                  'organic_cart=$cookie; Path=/api/v1; HttpOnly; SameSite=Lax',
            if (signedIn && r.headers['Cookie'] != null)
              'set-cookie': 'organic_cart=; Path=/api/v1; Max-Age=0',
          },
        );
      }
      expect(
        r.headers['Cookie'],
        isNull,
        reason: 'Guest cookie only belongs on cart requests',
      );
      return response({});
    });
    OrganicStore makeStore() => OrganicStore(
      api: OrganicApi(baseUrl: 'http://localhost/api/v1', client: client),
    );
    final first = makeStore();
    await first.add('v', 3);
    expect(first.loggedIn, false);
    expect(first.cartCount, 3);
    // MockClient has no shared transport to close.
    first.dispose();
    final second = makeStore();
    await second.initialize();
    expect(second.cartCount, 3);
    second.selectVoucher('VC10');
    await second.login('customer', 'password');
    expect(second.selectedVoucherCode, 'VC10');
    expect(second.cartCount, 5);
    expect(merges, 1);
    await second.refreshCart();
    expect(merges, 1);
    await second.logout();
    expect(second.selectedVoucherCode, '');
    expect(
      second.cartCount,
      0,
      reason: 'Private account cart is not exposed to the next guest',
    );
    await second.login('customer', 'password');
    expect(second.cartCount, 5);
    expect(merges, 1);
    second.dispose();
  });

  test(
    'simultaneous first guest additions share the newly issued cookie',
    () async {
      final cookie = 'a' * 43;
      var calls = 0;
      final firstReply = Completer<http.Response>();
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            calls++;
            if (calls == 1) return firstReply.future;
            expect(r.headers['Cookie'], 'organic_cart=$cookie');
            return response({'totalQuantity': 2});
          }),
        ),
      );
      final one = store.add('a', 1), two = store.add('b', 1);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      firstReply.complete(
        http.Response(
          jsonEncode({
            'data': {'totalQuantity': 1},
          }),
          200,
          headers: {'set-cookie': 'organic_cart=$cookie; Path=/api/v1'},
        ),
      );
      await Future.wait([one, two]);
      expect(calls, 2);
      expect(store.cartCount, 2);
      store.dispose();
    },
  );

  test('merge limit retains the guest identity for retry without duplicating additions', () async {
    final cookie = 'b' * 43;
    var reads = 0;
    final store = OrganicStore(
      api: OrganicApi(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            return http.Response(
              '{"data":{"totalQuantity":1}}',
              200,
              headers: {'set-cookie': 'organic_cart=$cookie; Path=/api/v1'},
            );
          }
          reads++;
          expect(r.headers['Cookie'], 'organic_cart=$cookie');
          return response({'mergeStatus': 'PENDING_LIMIT_QUANTITY'});
        }),
      ),
    );
    await store.add('v', 1);
    store.user = {'accountId': 'a'};
    store.api.setSession('a', 'r');
    await store.refreshCart();
    await store.refreshCart();
    expect(reads, 2);
    expect(store.cartService.hasGuestCart, true);
    store.dispose();
  });

  test(
    'a queued guest mutation cannot be submitted under another login',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            calls++;
            return pending.future;
          }),
        ),
      );
      final one = expectLater(store.add('a', 1), throwsA(isA<ApiException>()));
      final two = expectLater(store.add('b', 1), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      store.api.setSession('other', 'refresh');
      pending.complete(response({}));
      await Future.wait([one, two]);
      expect(calls, 1);
      store.dispose();
    },
  );
}
