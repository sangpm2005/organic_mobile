import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

class AccountError extends StatelessWidget {
  final OrganicStore store;
  const AccountError(this.store, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Panel(
      child: Column(
        children: [
          Text(store.accountError ?? 'Chưa tải được dữ liệu.'),
          TextButton(
            onPressed: store.refreshAccount,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
