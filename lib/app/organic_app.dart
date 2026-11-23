import 'package:flutter/material.dart';

import '../shared/widgets/visible_refresh.dart';

import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:organic_mobile/app/navigation/shop_shell.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../features/notifications/data/customer_push.dart';
import '../features/notifications/data/push_gateway.dart';
import '../features/orders/presentation/order_screen.dart';
import '../features/orders/data/payment_return_links.dart';
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
  final paymentLinks = PaymentReturnLinks();
  String? openingPayment;
  OrganicStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    subscription = store.push.events.listen(receive);
    unawaited(
      paymentLinks.start((uri) {
        final id = paymentReturnOrder(uri);
        if (id == null || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || openingPayment == id) return;
          if (!store.loggedIn) {
            messenger.currentState?.showSnackBar(
              const SnackBar(
                content: Text(
                  'Đăng nhập rồi mở Đơn hàng để xem kết quả thanh toán.',
                ),
              ),
            );
            return;
          }
          openingPayment = id;
          navigator.currentState
              ?.push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionBoundary(child: OrderScreen(id)),
                ),
              )
              .whenComplete(() => openingPayment = null);
        });
      }),
    );
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
    paymentLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: MaterialApp(
      navigatorObservers: [storefrontRoutes],
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
