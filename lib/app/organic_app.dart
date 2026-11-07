import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:organic_mobile/app/navigation/shop_shell.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../features/notifications/data/customer_push.dart';
import '../features/notifications/data/push_gateway.dart';
import '../features/orders/presentation/order_screen.dart';
import '../features/feedback/presentation/feedback_detail_screen.dart';
import '../features/returns/presentation/return_detail_screen.dart';
import '../shared/widgets/session_boundary.dart';

class OrganicApp extends StatefulWidget {
  final OrganicStore store;
  const OrganicApp({super.key, required this.store});
  @override
  State<OrganicApp> createState() => _OrganicAppState();
}

class _OrganicAppState extends State<OrganicApp> {
  final navigator = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<PushEvent>? subscription;
  final seen = <String>{};
  OrganicStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    subscription = store.push.events.listen(receive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = store.push.pendingOpen;
      if (mounted && pending != null) receive(pending);
    });
  }

  void receive(PushEvent event) {
    if (!mounted ||
        !store.loggedIn ||
        event.data['accountId'] != store.user?['accountId']) {
      return;
    }
    unawaited(store.refreshAccount(force: true));
    if (!event.opened) {
      final id = '${event.data['notificationId']}';
      if (seen.add(id)) {
        messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn có cập nhật mới từ cửa hàng. Xem trong Thông báo.',
            ),
          ),
        );
      }
      return;
    }
    store.push.pendingOpen = null;
    final destination = notificationDestination(event.data);
    if (destination == null) return;
    final page = switch (destination.kind) {
      'don-hang' => OrderScreen(destination.id),
      'phan-hoi' => FeedbackDetailScreen(destination.id),
      _ => ReturnDetailScreen(destination.id),
    };
    final id = '${event.data['notificationId'] ?? ''}';
    if (id.isNotEmpty) {
      unawaited(
        store.notificationService
            .read(id)
            .then((_) => store.refreshAccount(force: true))
            .catchError((Object _) {}),
      );
    }
    navigator.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => SessionBoundary(child: page)),
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: messenger,
      title: 'organicfood',
      debugShowCheckedModeBanner: false,
      theme: organicTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ShopShell(),
    ),
  );
}
