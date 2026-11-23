import 'package:flutter/material.dart';

import '../../../../core/media/upload_file.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/json.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/widgets/attachment_picker.dart';
import '../../../../shared/media/media_validation.dart';
import '../../domain/feedback_labels.dart';

class FeedbackComposer extends StatefulWidget {
  final String? feedbackId, orderId;
  final bool canUpload;
  final VoidCallback onSaved, onUncertain;
  final ValueChanged<String>? onCreated;
  const FeedbackComposer({
    super.key,
    this.feedbackId,
    this.orderId,
    this.canUpload = true,
    required this.onSaved,
    required this.onUncertain,
    this.onCreated,
  });
  @override
  State<FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends State<FeedbackComposer> {
  final form = GlobalKey<FormState>(),
      subject = TextEditingController(),
      content = TextEditingController();
  String type = 'product';
  List<UploadFile> files = [];
  final Set<int> uploaded = {};
  bool busy = false, uncertain = false;
  String? feedbackId, messageId, error;
  bool saved = false;
  @override
  void dispose() {
    subject.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || uncertain || !form.currentState!.validate()) return;
    final store = StoreScope.of(context),
        version = StoreScope.of(context).api.sessionVersion;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      validateMedia(files);
      if (!saved) {
        if (widget.feedbackId == null) {
          final detail = await store.feedbackService.create({
            'orderId': widget.orderId,
            'feedbackType': type,
            'subject': subject.text.trim(),
            'content': content.text.trim(),
          });
          feedbackId = '${object(detail['feedback'])['id']}';
        } else {
          feedbackId = widget.feedbackId;
          final message = await store.feedbackService.reply(
            feedbackId!,
            content.text.trim(),
          );
          messageId = '${message['id']}';
        }
        saved = true;
      }
      for (var i = 0; i < files.length; i++) {
        if (store.api.sessionVersion != version) return;
        if (!uploaded.contains(i)) {
          await store.feedbackService.upload(
            feedbackId!,
            files[i],
            messageId: messageId,
          );
          uploaded.add(i);
        }
      }
      if (!mounted || store.api.sessionVersion != version) return;
      if (widget.feedbackId == null) {
        widget.onCreated?.call(feedbackId!);
      } else {
        content.clear();
        setState(() {
          files = [];
          uploaded.clear();
          saved = false;
          messageId = null;
        });
        widget.onSaved();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = saved
            ? 'Nội dung đã gửi. Một số tệp chưa xác nhận tải lên: $e'
            : '$e';
        uncertain =
            e is! ApiException ||
            e.status == null ||
            e.status! >= 500 ||
            [408, 429].contains(e.status);
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.feedbackId == null) ...[
          DropdownButtonFormField<String>(
            key: const ValueKey('feedback.type'),
            initialValue: type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nội dung cần hỗ trợ'),
            items: feedbackTypes.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: busy || saved || uncertain
                ? null
                : (v) => setState(() => type = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('feedback.subject'),
            controller: subject,
            enabled: !busy && !saved && !uncertain,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Chủ đề *',
              hintText: 'Nhập chủ đề hoặc chọn gợi ý bên dưới',
            ),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập chủ đề.' : null,
          ),
          Text(
            'Gợi ý chủ đề · Chạm để điền, bạn vẫn có thể sửa lại',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final suggestion in feedbackSubjectSuggestions[type]!)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: busy || saved || uncertain
                      ? null
                      : () {
                          subject.value = TextEditingValue(
                            text: suggestion,
                            selection: TextSelection.collapsed(
                              offset: suggestion.length,
                            ),
                          );
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          key: const ValueKey('feedback.content'),
          controller: content,
          enabled: !busy && !saved && !uncertain,
          minLines: 3,
          maxLines: 8,
          maxLength: 10000,
          decoration: InputDecoration(
            labelText: widget.feedbackId == null
                ? 'Mô tả vấn đề *'
                : 'Tin nhắn của bạn *',
          ),
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập nội dung.' : null,
        ),
        if (widget.canUpload)
          AttachmentPicker(
            files: files,
            onChanged: (v) => setState(() => files = v),
            enabled: !busy && !saved && !uncertain,
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (uncertain)
          const Text(
            'Chưa rõ kết quả. Hãy kiểm tra nội dung đã lưu trước khi gửi thêm để tránh trùng.',
          ),
        if (uncertain || saved)
          TextButton(
            onPressed: busy
                ? null
                : () {
                    if (saved && widget.feedbackId == null) {
                      widget.onCreated?.call(feedbackId!);
                    } else {
                      if (widget.feedbackId != null) {
                        setState(() {
                          uncertain = false;
                          saved = false;
                          error = null;
                          files = [];
                          uploaded.clear();
                          messageId = null;
                          content.clear();
                        });
                      }
                      widget.onUncertain();
                    }
                  },
            child: const Text('Kiểm tra nội dung đã gửi'),
          ),
        FilledButton(
          onPressed: busy || uncertain ? null : send,
          child: Text(
            busy
                ? 'Đang gửi…'
                : saved
                ? 'Tải lại tệp còn thiếu'
                : widget.feedbackId == null
                ? 'Gửi phản hồi'
                : 'Gửi tin nhắn',
          ),
        ),
      ],
    ),
  );
}
