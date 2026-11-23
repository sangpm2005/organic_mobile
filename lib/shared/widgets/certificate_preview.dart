import 'package:flutter/material.dart';

import '../../core/utils/json.dart';
import '../navigation/navigation.dart';

class CertificatePreview extends StatelessWidget {
  final Json certificate;
  final double height;
  const CertificatePreview(this.certificate, {super.key, this.height = 180});
  static String? image(Json row) {
    for (final key in ['previewImageUrl', 'imageUrl', 'documentUrl']) {
      final raw = '${row[key] ?? ''}';
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }
      if (key != 'documentUrl' ||
          RegExp(
            r'\.(png|jpe?g|webp)(?:$|\?)',
            caseSensitive: false,
          ).hasMatch(raw)) {
        return raw;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = image(certificate);
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () => open(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('Ảnh chứng nhận')),
            body: InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) =>
                      const Text('Chưa tải được ảnh chứng nhận.'),
                ),
              ),
            ),
          ),
        ),
        child: Image.network(
          url,
          width: double.infinity,
          height: height,
          fit: BoxFit.contain,
          semanticLabel:
              'Ảnh ${certificate['name'] ?? certificate['certificateName'] ?? 'chứng nhận'}',
          errorBuilder: (_, _, _) => const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Mở hồ sơ để xem tài liệu gốc'),
          ),
        ),
      ),
    );
  }
}
