import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';

class SessionBoundary extends StatefulWidget {
  final Widget child;
  const SessionBoundary({super.key, required this.child});
  @override
  State<SessionBoundary> createState() => _SessionBoundaryState();
}

class _SessionBoundaryState extends State<SessionBoundary> {
  int? version;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    version ??= store.api.sessionVersion;
    if (store.loggedIn && version == store.api.sessionVersion) {
      return widget.child;
    }
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        'Phiên đăng nhập đã thay đổi',
        'Vui lòng trở về trang chính và mở lại chức năng này.',
        action: FilledButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Về trang chính'),
        ),
      ),
    );
  }
}
