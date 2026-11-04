import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/customer_detail.dart';
import '../../../shared/widgets/paged_records.dart';
import '../../../shared/widgets/panel.dart';
import '../../../shared/widgets/note_dialog.dart';
import '../../../shared/widgets/remote_attachments.dart';
import '../../orders/presentation/order_screen.dart';
import '../../returns/domain/return_labels.dart';
import '../domain/feedback_labels.dart';
import 'widgets/feedback_composer.dart';

class FeedbackDetailScreen extends StatefulWidget {
  final String id;
  const FeedbackDetailScreen(this.id, {super.key});
  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  int revision = 0;
  bool busy = false;
  Future<void> change(bool reopen, Future<void> Function() reload) async {
    final store = StoreScope.of(context);
    final note = await askNote(
      context,
      reopen ? 'Mở lại phản hồi' : 'Đóng phản hồi',
      maxLength: 1000,
    );
    if (note == null || !mounted) return;
    setState(() => busy = true);
    try {
      await store.feedbackService.close(widget.id, note, reopen: reopen);
      await reload();
      if (mounted) setState(() => revision++);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), service = store.feedbackService;
    return CustomerDetail(
      title: 'Chi tiết phản hồi',
      load: () async {
        final data = await service.detail(widget.id);
        try {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            await store.notificationService.readThread(feedbackId: widget.id);
          }
        } catch (_) {
          /* Reading stays available offline from notifications. */
        }
        return data;
      },
      builder: (data, reload) {
        final f = object(data['feedback']), actions = object(data['actions']);
        return PagedRecords(
          refreshToken: '$revision:${data['messageCount']}:${f['updatedAt']}',
          load: (p) => service.messages(widget.id, p),
          empty: 'Chưa có tin nhắn trao đổi.',
          header: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${f['subject']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SelectableText('${f['feedbackCode']}'),
                  Text(feedbackStates[f['status']] ?? '${f['status']}'),
                  const SizedBox(height: 12),
                  Text('${data['content']}'),
                  if (object(f['assignedEmployee'])['fullName'] != null)
                    Text(
                      'Nhân viên hỗ trợ: ${object(f['assignedEmployee'])['fullName']}',
                    ),
                  if (object(f['order'])['id'] != null)
                    TextButton(
                      onPressed: () => open(
                        context,
                        OrderScreen('${object(f['order'])['id']}'),
                        account: true,
                      ),
                      child: const Text('Xem đơn hàng liên quan'),
                    ),
                ],
              ),
            ),
            RemoteAttachments(
              objects(data['media']),
              onDelete: (file) async {
                await service.deleteMedia(widget.id, '${file['id']}');
                await reload();
                if (mounted) setState(() => revision++);
              },
            ),
            Wrap(
              spacing: 8,
              children: [
                if (actions['canClose'] == true)
                  OutlinedButton(
                    onPressed: busy ? null : () => change(false, reload),
                    child: const Text('Đóng phản hồi'),
                  ),
                if (actions['canReopen'] == true)
                  OutlinedButton(
                    onPressed: busy ? null : () => change(true, reload),
                    child: const Text('Mở lại phản hồi'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (actions['canReply'] == true)
              FeedbackComposer(
                key: ValueKey('reply:${widget.id}'),
                feedbackId: widget.id,
                canUpload: actions['canUpload'] == true,
                onSaved: () {
                  reload();
                  setState(() => revision++);
                },
                onUncertain: () {
                  reload();
                  setState(() => revision++);
                },
              )
            else
              const Text('Phản hồi hiện không nhận thêm tin nhắn.'),
            const SizedBox(height: 22),
            Text(
              'Trao đổi (${data['messageCount'] ?? 0})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          itemBuilder: (m) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m['senderName'] ?? (m['senderType'] == 'customer' ? 'Bạn' : 'organicfood')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    dateText(m['createdAt']),
                    style: const TextStyle(fontSize: 11),
                  ),
                  SelectableText(
                    m['messageType'] == 'text'
                        ? '${m['content']}'
                        : supportHistoryText('${m['content']}'),
                  ),
                  RemoteAttachments(
                    objects(m['media']),
                    onDelete: (file) async {
                      await service.deleteMedia(widget.id, '${file['id']}');
                      await reload();
                      if (mounted) setState(() => revision++);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
