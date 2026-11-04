import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/returns/data/returns_repository.dart';

import '../../helpers/customer_fixtures.dart';

class UnavailableStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #write) {
      return Future<void>.error(StateError('storage unavailable'));
    }
    if (invocation.memberName == #read) return Future<String?>.value(null);
    if (invocation.memberName == #delete) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'return is never sent before its retry record can be persisted',
    () async {
      var writes = 0;
      final store = OrganicStore(
        storage: UnavailableStorage(),
        returnDraftFiles: MemoryReturnFiles(),
        api: OrganicApi(
          client: MockClient((r) async {
            writes++;
            return response({});
          }),
        ),
      );
      store.user = {'accountId': 'a'};
      store.api.setSession('access', 'refresh');
      await expectLater(
        store.submitReturn(payload: returnPayload, files: [image()]),
        throwsA(isA<ApiException>()),
      );
      await expectLater(store.submitReturn(), throwsA(isA<ApiException>()));
      expect(writes, 0);
      expect(store.pendingReturn, isNotNull);
      store.dispose();
    },
  );
  test(
    'uncertain return keeps exact payload, key and evidence after app restart',
    () async {
      final files = MemoryReturnFiles();
      String? key;
      final store = customer(
        MockClient((r) async {
          key = r.headers['Idempotency-Key'];
          expect(jsonDecode(jsonPart(r, 'request')), returnPayload);
          return response({}, 503);
        }),
        files: files,
      );
      await expectLater(
        store.submitReturn(payload: returnPayload, files: [image()]),
        throwsA(isA<ApiException>()),
      );
      expect(store.pendingReturn, isNotNull);
      expect(files.files[key]!.single.bytes, image().bytes);
      store.dispose();
      var creates = 0;
      final restored = OrganicStore(
        returnDraftFiles: files,
        api: OrganicApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/return-requests')) {
              creates++;
              expect(r.headers['Idempotency-Key'], key);
              expect(jsonDecode(jsonPart(r, 'request')), returnPayload);
              return response({
                'request': {'id': 'confirmed'},
              });
            }
            return response([]);
          }),
        ),
      );
      await restored.initialize();
      expect((await restored.submitReturn())['request']['id'], 'confirmed');
      expect(creates, 1);
      expect(restored.pendingReturn, isNull);
      expect(files.files, isEmpty);
      restored.dispose();
    },
  );
  test('return submission requires images and preserves a pending request against changed content', () async {
    var calls = 0;
    final store = customer(
      MockClient((r) async {
        calls++;
        return response({}, 503);
      }),
    );
    await expectLater(
      store.submitReturn(payload: returnPayload, files: []),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
    await expectLater(
      store.submitReturn(payload: returnPayload, files: [image()]),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      store.submitReturn(
        payload: {...returnPayload, 'description': 'changed'},
        files: [image()],
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
    store.dispose();
  });
  test(
    'duplicate return taps submit once and logout discards late response',
    () async {
      final began = Completer<void>(), late = Completer<http.Response>();
      var calls = 0;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/return-requests')) {
            calls++;
            began.complete();
            return late.future;
          }
          return response({});
        }),
      );
      final first = expectLater(
        store.submitReturn(payload: returnPayload, files: [image()]),
        throwsA(isA<ApiException>()),
      );
      final second = expectLater(
        store.submitReturn(payload: returnPayload, files: [image()]),
        throwsA(isA<ApiException>()),
      );
      await began.future;
      await store.logout();
      late.complete(
        response({
          'request': {'id': 'private'},
        }),
      );
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(store.pendingReturn, isNull);
      expect(store.loggedIn, false);
      store.dispose();
    },
  );
  test('definitive rejection clears return draft and missing image cache never submits', () async {
    final files = MemoryReturnFiles();
    var status = 503, calls = 0;
    final store = customer(
      MockClient((r) async {
        calls++;
        return response({}, status);
      }),
      files: files,
    );
    await expectLater(
      store.submitReturn(payload: returnPayload, files: [image()]),
      throwsA(isA<ApiException>()),
    );
    status = 409;
    await expectLater(store.submitReturn(), throwsA(isA<ApiException>()));
    expect(store.pendingReturn, isNull);
    expect(files.files, isEmpty);
    store.pendingReturn = {
      'key': OrganicStore.newIdempotencyKey(),
      'payload': returnPayload,
    };
    await expectLater(store.submitReturn(), throwsA(isA<ApiException>()));
    expect(calls, 2);
    store.dispose();
  });
  test('customer proposals send displayed version and never invoke management actions', () async {
    var calls = 0;
    final api = OrganicApi(
      client: MockClient((r) async {
        calls++;
        expect(r.url.path, '/api/v1/return-requests/r/accept');
        expect(jsonDecode(r.body), {'note': 'Đồng ý', 'proposalVersion': 2});
        return response({}, 409);
      }),
    );
    final service = ReturnsRepository(api);
    await expectLater(
      service.action('r', 'refund', ''),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      service.action('r', 'accept', ''),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      service.action('r', 'accept', 'Đồng ý', proposalVersion: 2),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
    api.close();
  });
}
