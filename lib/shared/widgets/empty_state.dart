import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.eco_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: sage,
          child: Icon(icon, size: 36, color: moss),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.7),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}
