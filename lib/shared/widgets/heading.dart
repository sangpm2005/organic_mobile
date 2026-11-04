import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class Heading extends StatelessWidget {
  final String title, eyebrow;
  final Widget? trailing;
  const Heading(this.title, {super.key, this.eyebrow = '', this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: moss,
                    fontSize: 9,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
