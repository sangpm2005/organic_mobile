import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:organic_mobile/app/navigation/shop_shell.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class OrganicApp extends StatelessWidget {
  final OrganicStore store;
  const OrganicApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: MaterialApp(
      title: 'Mộc Organic',
      debugShowCheckedModeBanner: false,
      theme: organicTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ShopShell(),
    ),
  );
}
