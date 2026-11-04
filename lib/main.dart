import 'package:flutter/material.dart';

import 'app/organic_app.dart';
import 'app/state/organic_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = OrganicStore();
  await store.initialize();
  runApp(OrganicApp(store: store));
}
