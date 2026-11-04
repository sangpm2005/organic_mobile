import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';

class StoreScope extends InheritedNotifier<OrganicStore> {
  const StoreScope({
    super.key,
    required OrganicStore store,
    required super.child,
  }) : super(notifier: store);
  static OrganicStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
