import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:mime/mime.dart';

import '../../core/media/upload_file.dart';
import '../../core/network/api_exception.dart';
import '../media/media_validation.dart';
import '../navigation/navigation.dart';

class AttachmentPicker extends StatefulWidget {
  final List<UploadFile> files;
  final ValueChanged<List<UploadFile>> onChanged;
  final bool imagesOnly, enabled;
  const AttachmentPicker({
    super.key,
    required this.files,
    required this.onChanged,
    this.imagesOnly = false,
    this.enabled = true,
  });
  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> {
  bool picking = false;
  Future<void> pick() async {
    setState(() => picking = true);
    try {
      final selected = await openFiles(
        acceptedTypeGroups: [
          XTypeGroup(
            label: widget.imagesOnly ? 'Ảnh minh chứng' : 'Ảnh/video',
            extensions: [
              'jpg',
              'jpeg',
              'png',
              'webp',
              if (!widget.imagesOnly) ...['mp4', 'webm'],
            ],
            mimeTypes: [
              'image/jpeg',
              'image/png',
              'image/webp',
              if (!widget.imagesOnly) ...['video/mp4', 'video/webm'],
            ],
            uniformTypeIdentifiers: [
              'public.image',
              if (!widget.imagesOnly) 'public.movie',
            ],
          ),
        ],
      );
      if (!mounted || !widget.enabled) return;
      if (widget.files.length + selected.length > (widget.imagesOnly ? 5 : 6)) {
        throw const ApiException('Bạn đã chọn quá số tệp cho phép.');
      }
      final next = [...widget.files];
      for (final file in selected) {
        if (await file.length() > (widget.imagesOnly ? 5 : 50) * 1024 * 1024) {
          throw const ApiException(
            'Tệp quá lớn. Ảnh tối đa 5 MB, video tối đa 50 MB.',
          );
        }
        final bytes = await file.readAsBytes();
        next.add(
          UploadFile(
            file.name,
            lookupMimeType(file.name, headerBytes: bytes.take(32).toList()) ??
                file.mimeType ??
                '',
            bytes,
          ),
        );
      }
      validateMedia(next, imagesOnly: widget.imagesOnly);
      if (mounted && widget.enabled) widget.onChanged(next);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: !widget.enabled || picking ? null : pick,
        icon: const Icon(Icons.attach_file),
        label: Text(
          picking
              ? 'Đang chọn…'
              : widget.imagesOnly
              ? 'Thêm ảnh đại diện'
              : 'Thêm ảnh ',
        ),
      ),
      Text(
        widget.imagesOnly
            ? 'Tối đa 5 ảnh, mỗi ảnh 5 MB.'
            : 'Tối đa 5 ảnh (5 MB/ảnh) .',
        style: const TextStyle(fontSize: 11),
      ),
      for (var i = 0; i < widget.files.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: widget.files[i].isImage
              ? Image.memory(
                  widget.files[i].bytes,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.image_not_supported_outlined),
                )
              : const Icon(Icons.movie_outlined),
          title: Text(
            widget.files[i].name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${(widget.files[i].bytes.length / 1024).ceil()} KB'),
          trailing: IconButton(
            onPressed: !widget.enabled || picking
                ? null
                : () => widget.onChanged([...widget.files]..removeAt(i)),
            icon: const Icon(Icons.close),
            tooltip: 'Bỏ tệp',
          ),
        ),
    ],
  );
}
