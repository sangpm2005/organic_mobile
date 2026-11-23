import 'package:flutter/material.dart';

/// Format the saved description without adding brand or certification claims.
class ProductDescription extends StatelessWidget {
  final String text;
  const ProductDescription(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line
          in (text.trim().isEmpty ? 'Chưa có mô tả.' : text)
              .split(RegExp(r'\r?\n'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty))
        _paragraph(context, line),
    ],
  );

  Widget _paragraph(BuildContext context, String line) {
    final bold =
        line.startsWith('**') && line.endsWith('**') && line.length >= 4;
    final heading = bold || RegExp(r'^(?:\d+[.)]\s+|#{1,4}\s+)').hasMatch(line);
    final text = bold
        ? line.substring(2, line.length - 2)
        : line.replaceFirst(RegExp(r'^#{1,4}\s+'), '');
    return Padding(
      padding: EdgeInsets.only(top: heading ? 8 : 0, bottom: 12),
      child: Semantics(
        header: heading,
        child: Text(
          text,
          style: heading ? Theme.of(context).textTheme.titleSmall : null,
        ),
      ),
    );
  }
}
