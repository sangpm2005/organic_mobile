import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/json.dart';
import '../navigation/navigation.dart';

class RemoteAttachments extends StatelessWidget {
  final List<Json> media;
  final Future<void> Function(Json file)? onDelete;
  final bool account;
  const RemoteAttachments(
    this.media, {
    super.key,
    this.onDelete,
    this.account = true,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final file in media)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: file['mediaType'] == 'image'
              ? Image.network(
                  '${file['thumbnailUrl'] ?? file['mediaUrl']}',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                )
              : const Icon(Icons.play_circle_outline),
          title: Text(
            '${file['originalFilename'] ?? (file['mediaType'] == 'image' ? 'Ảnh đính kèm' : 'Video đính kèm')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final uri = Uri.tryParse('${file['mediaUrl']}');
            if (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty) {
              toast(context, 'Liên kết tệp chưa hợp lệ.');
              return;
            }
            if (file['mediaType'] == 'image') {
              await open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Ảnh đính kèm')),
                  body: InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        uri.toString(),
                        errorBuilder: (_, _, _) =>
                            const Text('Chưa tải được ảnh.'),
                      ),
                    ),
                  ),
                ),
                account: account,
              );
            } else if (!await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                ) &&
                context.mounted) {
              toast(context, 'Chưa mở được video.');
            }
          },
          trailing: onDelete != null && file['canDelete'] == true
              ? IconButton(
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xóa tệp đính kèm?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Giữ lại'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) {
                      try {
                        await onDelete!(file);
                      } catch (e) {
                        if (context.mounted) toast(context, e);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                )
              : null,
        ),
    ],
  );
}
