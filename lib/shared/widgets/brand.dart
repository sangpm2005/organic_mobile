import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.spa_outlined, color: moss, size: 30),
      SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'mộc.',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Text(
            'ORGANIC LIVING',
            style: TextStyle(fontSize: 7, letterSpacing: 2.4, color: moss),
          ),
        ],
      ),
    ],
  );
}
