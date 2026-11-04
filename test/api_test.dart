import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/api.dart';
import 'package:organic_mobile/core/models.dart';

http.Response reply(dynamic data, {int status = 200}) => http.Response(
  jsonEncode({'statusCode': status, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  test(
    'a malformed successful order response remains an uncertain failure',
    () async {
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient(
          (_) async => http.Response('<html>proxy error</html>', 201),
        ),
      );
      await expectLater(
        api.request('POST', '/orders', idempotencyKey: 'same-order'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.status,
            'uncertain status',
            isNull,
          ),
        ),
      );
      api.close();
    },
  );
  test(
    'public catalog omits stale credentials and encodes Vietnamese search',
    () async {
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], isNull);
          expect(request.url.queryParameters['keyword'], 'cà rốt & hạt');
          return reply({'content': []});
        }),
      )..accessToken = 'expired-private-token';
      expect(
        await api.request(
          'GET',
          '/products',
          authenticated: false,
          query: {'keyword': 'cà rốt & hạt'},
        ),
        {'content': []},
      );
      api.close();
    },
  );
  test(
    '401 refresh retries order with unchanged payload and idempotency key',
    () async {
      var attempts = 0, refreshes = 0, saves = 0;
      final api =
          OrganicApi(
              baseUrl: 'http://localhost/api/v1',
              client: MockClient((request) async {
                if (request.url.path.endsWith('/auth/refresh-token')) {
                  refreshes++;
                  expect(jsonDecode(request.body), {
                    'refreshToken': 'refresh-one',
                  });
                  expect(request.headers['Authorization'], isNull);
                  return reply({
                    'accessToken': 'access-two',
                    'refreshToken': 'refresh-two',
                  });
                }
                attempts++;
                expect(request.headers['Idempotency-Key'], 'same-order');
                expect(jsonDecode(request.body), {'points': 0});
                if (attempts == 1) {
                  return reply(null, status: 401);
                }
                expect(request.headers['Authorization'], 'Bearer access-two');
                return reply({'id': 'order-one'}, status: 201);
              }),
            )
            ..accessToken = 'access-one'
            ..refreshToken = 'refresh-one';
      api.onSessionChanged = () async {
        saves++;
      };
      expect(
        await api.request(
          'POST',
          '/orders',
          body: {'points': 0},
          idempotencyKey: 'same-order',
        ),
        {'id': 'order-one'},
      );
      expect([attempts, refreshes, saves], [2, 1, 1]);
      api.close();
    },
  );
  test(
    'expired refresh clears the private session without retry loops',
    () async {
      var calls = 0;
      final api =
          OrganicApi(
              baseUrl: 'http://localhost/api/v1',
              client: MockClient((_) async {
                calls++;
                return reply(null, status: 401);
              }),
            )
            ..accessToken = 'old'
            ..refreshToken = 'old-refresh';
      await expectLater(
        api.request('GET', '/orders'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 2);
      expect(api.accessToken, isNull);
      expect(api.refreshToken, isNull);
      api.close();
    },
  );
  test(
    'temporary refresh failure retains session and allows a later retry',
    () async {
      var fail = true;
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh-token')) {
            if (fail) throw http.ClientException('offline');
            return reply({'accessToken': 'new', 'refreshToken': 'new-refresh'});
          }
          return reply(
            {},
            status: r.headers['Authorization'] == 'Bearer new' ? 200 : 401,
          );
        }),
      )..setSession('old', 'refresh');
      await expectLater(
        api.request('GET', '/cart'),
        throwsA(isA<ApiException>()),
      );
      expect(api.accessToken, 'old');
      expect(api.refreshToken, 'refresh');
      fail = false;
      await api.request('GET', '/cart');
      expect(api.accessToken, 'new');
      api.close();
    },
  );
  test('late refresh cannot replace a newly logged-in account', () async {
    final started = Completer<void>(), response = Completer<http.Response>();
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh-token')) {
          started.complete();
          return response.future;
        }
        return reply({}, status: 401);
      }),
    )..setSession('account-a', 'refresh-a');
    final pending = expectLater(
      api.request('GET', '/cart'),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    api.setSession('account-b', 'refresh-b');
    response.complete(
      reply({'accessToken': 'late-a', 'refreshToken': 'late-refresh-a'}),
    );
    await pending;
    expect(api.accessToken, 'account-b');
    expect(api.refreshToken, 'refresh-b');
    api.close();
  });
  test(
    'concurrent expired requests share one refresh and preserve their payloads',
    () async {
      var refreshes = 0;
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh-token')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return reply({'accessToken': 'new', 'refreshToken': 'new-refresh'});
          }
          return reply({
            'path': r.url.path,
          }, status: r.headers['Authorization'] == 'Bearer new' ? 200 : 401);
        }),
      )..setSession('old', 'refresh');
      await Future.wait(
        ['/cart', '/orders', '/customers/me'].map((p) => api.request('GET', p)),
      );
      expect(refreshes, 1);
      api.close();
    },
  );
}
