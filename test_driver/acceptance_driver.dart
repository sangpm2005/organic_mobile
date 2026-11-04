import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('../.local/acceptance/20261028-uat/artifacts');
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final clean = {...?data}..remove('screenshots');
      await File('${directory.path}/driver-result.json')
          .writeAsString(jsonEncode(clean));
    },
  );
}
