import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

class ProductPhoto extends StatelessWidget {
  final String url;
  final double? height;
  const ProductPhoto(this.url, {super.key, this.height});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: sage,
    child: url.isEmpty
        ? SizedBox(
            height: height,
            child: const Center(
              child: Icon(Icons.eco_outlined, size: 45, color: moss),
            ),
          )
        : Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => SizedBox(
              height: height,
              child: const Center(
                child: Icon(Icons.eco_outlined, size: 45, color: moss),
              ),
            ),
          ),
  );
}
