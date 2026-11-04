import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/media/upload_file.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/returns/data/pending_return_files.dart';

http.Response response(dynamic data, [int status = 200]) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
UploadFile image([String name = 'evidence.png']) => UploadFile(
  name,
  'image/png',
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a/uoAAAAASUVORK5CYII=',
  ),
);

class MemoryReturnFiles extends ReturnDraftFiles {
  final Map<String, List<UploadFile>> files = {};
  @override
  Future<void> put(String key, List<UploadFile> value) async {
    files[key] = List.of(value);
  }

  @override
  Future<List<UploadFile>> read(String key) async {
    if (!files.containsKey(key)) throw const ApiException('Missing draft');
    return files[key]!;
  }

  @override
  Future<void> remove(String key) async {
    files.remove(key);
  }
}

OrganicStore customer(http.Client client, {MemoryReturnFiles? files}) {
  final store = OrganicStore(
    api: OrganicApi(baseUrl: 'http://localhost/api/v1', client: client),
    returnDraftFiles: files ?? MemoryReturnFiles(),
  );
  store.user = {'accountId': 'a', 'username': 'customer-a'};
  store.api.setSession('access', 'refresh');
  return store;
}

String jsonPart(http.Request request, String name) {
  final body = utf8.decode(request.bodyBytes, allowMalformed: true);
  final value = RegExp('name="$name"\\r\\n\\r\\n([^\\r\\n]*)')
      .firstMatch(body)
      ?.group(1);
  if (value == null) throw StateError('JSON part $name not found');
  return value;
}

const returnPayload = {
  'orderId': 'order-a',
  'requestType': 'return_refund',
  'reason': 'damaged',
  'description': 'Hàng bị hư khi giao đến.',
  'items': [
    {'orderDetailId': 'line-a', 'quantity': 1, 'reason': 'damaged'},
  ],
};
