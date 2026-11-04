import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/media/upload_file.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/attachment_picker.dart';
import '../../../shared/widgets/panel.dart';

class ReviewCreateScreen extends StatefulWidget {
  final Json purchase;
  const ReviewCreateScreen(this.purchase, {super.key});
  @override
  State<ReviewCreateScreen> createState() => _ReviewCreateScreenState();
}

class _ReviewCreateScreenState extends State<ReviewCreateScreen> {
  final form = GlobalKey<FormState>(), content = TextEditingController();
  int rating = 0;
  bool initialized = false, busy = false, uncertain = false, preview = false;
  String? draftKey, error;
  List<UploadFile> files = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      loadDraft();
    }
  }

  Future<void> loadDraft() async {
    final store = StoreScope.of(context),
        version = StoreScope.of(context).api.sessionVersion;
    draftKey =
        'organicfood.reviewDraft.${store.user?['accountId'] ?? store.user?['username']}.${widget.purchase['orderDetailId']}';
    try {
      final raw = await store.storage.read(key: draftKey!);
      if (!mounted || version != store.api.sessionVersion || raw == null) {
        return;
      }
      final data = object(jsonDecode(raw));
      setState(() {
        rating = number(data['rating']).toInt().clamp(0, 5);
        content.text = '${data['content'] ?? ''}';
      });
    } catch (_) {
      /* Drafts are optional. */
    }
  }

  Future<void> saveDraft() async {
    final store = StoreScope.of(context);
    try {
      await store.storage.write(
        key: draftKey!,
        value: jsonEncode({'rating': rating, 'content': content.text}),
      );
      if (mounted) {
        toast(
          context,
          'Đã lưu nháp phần chữ. Ảnh/video cần chọn lại khi mở lại màn hình.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, 'Chưa lưu được nháp: $e');
    }
  }

  Future<void> send() async {
    if (busy || uncertain || !form.currentState!.validate()) return;
    if (rating < 1) {
      setState(() => error = 'Vui lòng chọn từ 1 đến 5 sao.');
      return;
    }
    final store = StoreScope.of(context),
        version = StoreScope.of(context).api.sessionVersion;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.reviewService.submit({
        'productId': widget.purchase['productId'],
        'orderDetailId': widget.purchase['orderDetailId'],
        'rating': rating,
        'content': content.text.trim(),
      }, files);
      if (!mounted || version != store.api.sessionVersion) return;
      try {
        await store.storage.delete(key: draftKey!);
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context, true);
        toast(context, 'Đã gửi đánh giá. Cảm ơn bạn!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          uncertain =
              e is! ApiException ||
              e.status == null ||
              e.status! >= 500 ||
              [408, 429].contains(e.status);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đánh giá sản phẩm')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${widget.purchase['productName']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${widget.purchase['variantName']} · Đơn ${widget.purchase['orderCode']}',
          ),
          Wrap(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: busy || uncertain
                      ? null
                      : () => setState(() => rating = i),
                  tooltip: '$i sao',
                  icon: Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade800,
                  ),
                ),
            ],
          ),
          TextFormField(
            key: const ValueKey('review.content'),
            controller: content,
            enabled: !busy && !uncertain,
            minLines: 4,
            maxLines: 10,
            maxLength: 3000,
            decoration: const InputDecoration(labelText: 'Cảm nhận của bạn *'),
            validator: (v) => (v?.trim().length ?? 0) < 10
                ? 'Bình luận cần ít nhất 10 ký tự.'
                : null,
          ),
          AttachmentPicker(
            files: files,
            onChanged: (v) => setState(() => files = v),
            enabled: !busy && !uncertain,
          ),
          const Text(
            'Ảnh/video không bắt buộc. Đánh giá đã gửi được giữ nguyên; bạn có thể xóa và viết lại.',
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (uncertain) ...[
            const Text(
              'Chưa rõ kết quả. Kiểm tra danh sách đánh giá trước khi gửi lại.',
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kiểm tra đánh giá đã gửi'),
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy || uncertain ? null : saveDraft,
                child: const Text('Lưu nháp'),
              ),
              OutlinedButton(
                onPressed: busy || uncertain
                    ? null
                    : () {
                        if (form.currentState!.validate() && rating > 0) {
                          setState(() => preview = !preview);
                        }
                      },
                child: const Text('Xem trước'),
              ),
            ],
          ),
          if (preview)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xem trước · $rating sao'),
                  Text(content.text.trim()),
                  Text('Đính kèm ${files.length} tệp'),
                ],
              ),
            ),
          FilledButton(
            onPressed: busy || uncertain ? null : send,
            child: Text(busy ? 'Đang gửi…' : 'Gửi đánh giá'),
          ),
        ],
      ),
    ),
  );
}
