import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class AmountRow extends StatelessWidget {
  final String label;
  final dynamic amount;
  final bool total;
  const AmountRow(this.label, this.amount, {super.key, this.total = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total ? ink : muted,
              fontWeight: total ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          money(amount),
          style: TextStyle(
            fontSize: total ? 20 : 13,
            fontWeight: total ? FontWeight.w600 : FontWeight.normal,
            color: total ? moss : ink,
          ),
        ),
      ],
    ),
  );
}
