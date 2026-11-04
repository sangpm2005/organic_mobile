import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/widgets/session_boundary.dart';

void toast(BuildContext context, Object message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$message'), behavior: SnackBarBehavior.floating),
  );
}

Future<T?> open<T>(BuildContext context, Widget page, {bool account = false}) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => account ? SessionBoundary(child: page) : page,
      ),
    );
