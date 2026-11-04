import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  test(
    'multipart refresh replays exact JSON, image bytes and idempotency key',
    () async {
      var submits = 0;
      final file = image();
      final payloads = <String>[];
      final api = OrganicApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh-token')) {
            return response({'accessToken': 'new-access'});
          }
          submits++;
          expect(r.headers['Idempotency-Key'], 'same-attempt');
          expect(
            r.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          payloads.add(jsonPart(r, 'request'));
          expect(r.bodyBytes, containsAllInOrder(file.bytes));
          final text = utf8.decode(r.bodyBytes, allowMalformed: true);
          expect(text, contains('name="images"; filename="evidence.png"'));
          expect(text, contains('content-type: image/png'));
          if (submits == 1) return response({}, 401);
          expect(r.headers['Authorization'], 'Bearer new-access');
          return response({
            'request': {'id': 'one'},
          });
        }),
      );
      api.setSession('expired', 'refresh');
      final result = await api.request(
        'POST',
        '/return-requests',
        body: returnPayload,
        files: [file],
        fileField: 'images',
        jsonPart: 'request',
        idempotencyKey: 'same-attempt',
      );
      expect(result['request']['id'], 'one');
      expect(submits, 2);
      expect(payloads, [jsonEncode(returnPayload), jsonEncode(returnPayload)]);
      api.close();
    },
  );
  test('late multipart response is discarded after account change', () async {
    final began = Completer<void>(), late = Completer<http.Response>();
    final api = OrganicApi(
      client: MockClient((r) async {
        began.complete();
        return late.future;
      }),
    );
    api.setSession('a', 'refresh-a');
    final result = expectLater(
      api.request(
        'POST',
        '/reviews/submission',
        body: {'content': 'private'},
        files: [image()],
        jsonPart: 'review',
      ),
      throwsA(isA<ApiException>()),
    );
    await began.future;
    api.setSession('b', 'refresh-b');
    late.complete(response({'id': 'private-review'}));
    await result;
    api.close();
  });
}
