import 'dart:async';

import 'package:flutter/material.dart';

final storefrontRoutes = RouteObserver<ModalRoute<void>>();

/// Only polls the foreground tab/route. A failed refresh retains current data.
class VisibleRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() refresh;
  final bool active;
  const VisibleRefresh({
    super.key,
    required this.child,
    required this.refresh,
    this.active = true,
  });
  @override
  State<VisibleRefresh> createState() => _VisibleRefreshState();
}

class _VisibleRefreshState extends State<VisibleRefresh>
    with WidgetsBindingObserver, RouteAware {
  Timer? timer;
  ModalRoute<void>? route;
  bool busy = false;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (route != next) {
      storefrontRoutes.unsubscribe(this);
      route = next;
      if (next != null) storefrontRoutes.subscribe(this, next);
    }
  }

  Future<void> refresh() async {
    if (!mounted ||
        busy ||
        !widget.active ||
        !foreground ||
        route?.isCurrent == false) {
      return;
    }
    busy = true;
    try {
      await widget.refresh();
    } catch (_) {
      /* Keep current content. */
    } finally {
      busy = false;
    }
  }

  @override
  void didPopNext() {
    refresh();
  }

  @override
  void didUpdateWidget(covariant VisibleRefresh old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refresh();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    storefrontRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
