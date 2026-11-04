import 'package:flutter/material.dart';

import '../../../../core/media/upload_file.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/widgets/attachment_picker.dart';

class AvatarEditor extends StatefulWidget {
  const AvatarEditor({super.key});
  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  List<UploadFile> files = [];
  bool busy = false;
  Future<void> save({bool delete = false}) async {
    final store = StoreScope.of(context);
    if (busy || !delete && files.length != 1) {
      toast(context, 'Vui lòng chọn đúng một ảnh đại diện.');
      return;
    }
    if (delete) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xóa ảnh đại diện?'),
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
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await store.api.request(
        delete ? 'DELETE' : 'POST',
        '/customers/me/avatar',
        files: delete ? null : files,
        fileField: 'file',
        timeout: const Duration(seconds: 60),
      );
      await store.refreshAccount(force: true);
      if (mounted) {
        setState(() => files = []);
        toast(
          context,
          delete ? 'Đã xóa ảnh đại diện.' : 'Đã cập nhật ảnh đại diện.',
        );
      }
    } catch (e) {
      await store.refreshAccount(force: true);
      if (mounted) {
        toast(
          context,
          '$e\nHồ sơ đã được tải lại; hãy kiểm tra ảnh trước khi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = '${StoreScope.of(context).profile?['avatarUrl'] ?? ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh đại diện', style: Theme.of(context).textTheme.titleLarge),
        if (url.isNotEmpty)
          Image.network(
            url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 60),
          ),
        AttachmentPicker(
          files: files,
          onChanged: (v) => setState(() => files = v),
          imagesOnly: true,
          enabled: !busy,
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy || files.length != 1 ? null : () => save(),
              child: Text(busy ? 'Đang xử lý…' : 'Lưu ảnh đại diện'),
            ),
            if (url.isNotEmpty)
              TextButton(
                onPressed: busy ? null : () => save(delete: true),
                child: const Text('Xóa ảnh đại diện'),
              ),
          ],
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
