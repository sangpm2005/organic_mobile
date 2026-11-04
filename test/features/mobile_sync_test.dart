import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/checkout/data/checkout_repository.dart';

http.Response reply(dynamic data, [int status = 200]) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
OrganicStore customer(http.Client client) {
  final store = OrganicStore(
    api: OrganicApi(baseUrl: 'http://localhost/api/v1', client: client),
  );
  store.api.setSession('a', 'r');
  store.user = {'accountId': 'customer-a'};
  store.rewards = {'available': 100};
  return store;
}

const offer = {
  'id': 'offer-a',
  'pointsCost': 10,
  'exchangeVersion': 'version-a',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'checkout refuses an ignored voucher and mutually exclusive direct points',
    () async {
      var calls = 0;
      final api = OrganicApi(
        client: MockClient((r) async {
          calls++;
          return reply({'voucherCode': null, 'voucherDiscount': 0});
        }),
      );
      final checkout = CheckoutRepository(api);
      await expectLater(
        checkout.preview({'voucherCode': 'MOC10', 'points': 0}),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        checkout.preview({'voucherCode': 'MOC10', 'points': 1}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
      api.close();
    },
  );
  test(
    'checkout accepts only the matching voucher with a real discount',
    () async {
      final api = OrganicApi(
        client: MockClient(
          (r) async => reply({'voucherCode': 'MOC10', 'voucherDiscount': 5000}),
        ),
      );
      final quote = await CheckoutRepository(api)
          .preview({'voucherCode': 'moc10', 'points': 0});
      expect(quote['voucherDiscount'], 5000);
      api.close();
    },
  );
  test(
    'uncertain exchange survives restart and reuses exact body and key',
    () async {
      String? originalKey, originalBody;
      final store = customer(
        MockClient((r) async {
          originalKey = r.headers['Idempotency-Key'];
          originalBody = r.body;
          return reply({}, 503);
        }),
      );
      await expectLater(
        store.exchangeVoucher(offer),
        throwsA(isA<ApiException>()),
      );
      expect(store.pendingVoucherExchange, isNotNull);
      store.dispose();
      var exchanges = 0;
      final restored = OrganicStore(
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/vouchers/exchange')) {
              exchanges++;
              expect(r.headers['Idempotency-Key'], originalKey);
              expect(r.body, originalBody);
              return reply({'voucherCode': 'ONCE'});
            }
            return reply([]);
          }),
        ),
      );
      await restored.initialize();
      expect(restored.pendingVoucherExchange, isNotNull);
      expect((await restored.exchangeVoucher())['voucherCode'], 'ONCE');
      expect(exchanges, 1);
      expect(restored.pendingVoucherExchange, isNull);
      restored.dispose();
    },
  );
  test('concurrent exchange taps submit once and late response cannot restore another session', () async {
    var calls = 0;
    final began = Completer<void>(), late = Completer<http.Response>();
    final store = customer(
      MockClient((r) async {
        if (r.url.path.endsWith('/vouchers/exchange')) {
          calls++;
          began.complete();
          return late.future;
        }
        return reply({});
      }),
    );
    final first = expectLater(
      store.exchangeVoucher(offer),
      throwsA(isA<ApiException>()),
    );
    final second = expectLater(
      store.exchangeVoucher(offer),
      throwsA(isA<ApiException>()),
    );
    await began.future;
    await store.logout();
    late.complete(reply({'voucherCode': 'PRIVATE'}));
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(store.pendingVoucherExchange, isNull);
    expect(store.loggedIn, false);
    store.dispose();
  });
  test(
    'definitive exchange rejection clears pending but 429 preserves it',
    () async {
      var status = 429;
      final store = customer(MockClient((r) async => reply({}, status)));
      await expectLater(
        store.exchangeVoucher(offer),
        throwsA(isA<ApiException>()),
      );
      expect(store.pendingVoucherExchange, isNotNull);
      status = 409;
      await expectLater(store.exchangeVoucher(), throwsA(isA<ApiException>()));
      expect(store.pendingVoucherExchange, isNull);
      store.dispose();
    },
  );
  test('inbox marks ownership endpoint and read state persists only for the current account', () async {
    final paths = <String>[];
    final store = customer(
      MockClient((r) async {
        paths.add('${r.method} ${r.url.path}');
        return reply({});
      }),
    );
    store.inbox = [
      {'id': 'notice', 'title': 'Từ Mộc'},
    ];
    await store.readUpdate({'kind': 'inbox', 'id': 'notice', 'read': false});
    expect(paths, contains('PATCH /api/v1/inbox/notice/read'));
    expect(store.inbox.single['readAt'], isNotNull);
    await store.readUpdate({'kind': 'promotion', 'key': 'promotion:a'});
    expect(store.readUpdates, contains('promotion:a'));
    await store.logout();
    expect(store.inbox, isEmpty);
    expect(store.readUpdates, isEmpty);
    store.dispose();
  });
}
