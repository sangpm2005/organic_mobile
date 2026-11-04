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
import '../../feedback/presentation/feedback_detail_screen.dart';
import '../../orders/presentation/order_screen.dart';
import '../domain/return_labels.dart';
import 'widgets/return_progress.dart';

class ReturnDetailScreen extends StatefulWidget {
  final String id;
  const ReturnDetailScreen(this.id, {super.key});
  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  bool busy = false;
  int revision = 0;
  Future<void> action(
    String action,
    Json request,
    Future<void> Function() reload,
  ) async {
    final service = StoreScope.of(context).returnsService;
    final version = number(request['proposalVersion']).toInt();
    final titles = {
      'accept': 'Đồng ý phương án lần $version',
      'decline': 'Đề nghị xét lại phương án',
      'cancel': 'Hủy yêu cầu',
      'submit-information': 'Bổ sung thông tin',
    };
    final note = await askNote(
      context,
      titles[action]!,
      required: action != 'accept',
      description: action == 'accept'
          ? 'Bạn đồng ý phương án đang hiển thị. Cửa hàng sẽ tiếp tục xử lý; thao tác này chưa xác nhận bạn đã nhận tiền hoàn hoặc hàng đổi.'
          : null,
    );
    if (note == null || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await service.action(widget.id, action, note, proposalVersion: version);
      await reload();
      if (mounted) setState(() => revision++);
    } catch (e) {
      await reload();
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), service = store.returnsService;
    return CustomerDetail(
      title: 'Chi tiết đổi trả',
      load: () async {
        final data = await service.detail(widget.id);
        try {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            await store.notificationService.readThread(
              returnRequestId: widget.id,
            );
          }
        } catch (_) {}
        return data;
      },
      builder: (data, reload) {
        final r = object(data['request']), actions = object(data['actions']);
        return PagedRecords(
          load: (p) => service.histories(widget.id, p),
          refreshToken: '$revision:${r['status']}:${r['proposalVersion']}',
          empty: 'Chưa có lịch sử xử lý.',
          header: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '${r['requestCode']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(returnStates[r['status']] ?? '${r['status']}'),
                  Text(returnTypes[r['requestType']] ?? '${r['requestType']}'),
                  Text(returnReasons[r['reason']] ?? '${r['reason']}'),
                  Text('${data['description']}'),
                  Text('Gửi lúc ${dateText(r['requestedAt'])}'),
                  if (object(r['assignedEmployee'])['fullName'] != null)
                    Text(
                      'Nhân viên hỗ trợ: ${object(r['assignedEmployee'])['fullName']}',
                    ),
                  TextButton(
                    onPressed: () => open(
                      context,
                      OrderScreen('${object(r['order'])['id']}'),
                      account: true,
                    ),
                    child: Text(
                      'Xem đơn gốc ${object(r['order'])['orderCode']}',
                    ),
                  ),
                  if (r['feedbackId'] != null)
                    TextButton(
                      onPressed: () => open(
                        context,
                        FeedbackDetailScreen('${r['feedbackId']}'),
                        account: true,
                      ),
                      child: const Text('Trao đổi & bổ sung ảnh/video'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  'accept': 'canAccept',
                  'decline': 'canDecline',
                  'cancel': 'canCancel',
                  'submit-information': 'canSubmitInformation',
                }.entries)
                  if (actions[e.value] == true)
                    OutlinedButton(
                      onPressed: busy ? null : () => action(e.key, r, reload),
                      child: Text(
                        const {
                          'accept': 'Đồng ý phương án',
                          'decline': 'Đề nghị xét lại',
                          'cancel': 'Hủy yêu cầu',
                          'submit-information': 'Bổ sung thông tin',
                        }[e.key]!,
                      ),
                    ),
              ],
            ),
            RemoteAttachments(objects(data['evidence'])),
            for (final item in objects(data['items']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['productName']} · ${item['variantName']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Đã yêu cầu: ${item['requestedQuantity']} · Được duyệt: ${number(r['proposalVersion']) > 0 ? item['approvedQuantity'] : 'Chưa xét duyệt'}',
                      ),
                      if (item['resolutionType'] != null)
                        Text(
                          '${returnTypes[item['resolutionType']] ?? item['resolutionType']} · ${item['returnRequired'] == true ? 'Cần gửi lại hàng' : 'Không thu hồi hàng'}',
                        ),
                      if (number(r['proposalVersion']) > 0)
                        Text(
                          'Tiền hoàn trong phương án: ${money(item['approvedRefundAmount'])}',
                        ),
                      if (item['policyAssessment'] != null)
                        Text('${item['policyAssessment']}'),
                      if (item['conditionNote'] != null)
                        Text('${item['conditionNote']}'),
                    ],
                  ),
                ),
              ),
            if (number(r['proposalVersion']) > 0)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phương án lần ${r['proposalVersion']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${data['decisionNote'] ?? ''}'),
                    if (data['policyNote'] != null)
                      Text('Căn cứ chính sách: ${data['policyNote']}'),
                    Text(
                      'Tổng tiền hoàn dự kiến: ${money(r['approvedRefundAmount'])}',
                    ),
                    const Text(
                      'Phương án được duyệt chưa phải tiền đã hoàn hoặc hàng đổi đã giao.',
                    ),
                  ],
                ),
              ),
            if (['processing', 'completed'].contains(r['status']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ReturnProgress(
                  widget.id,
                  returnRequired: r['returnRequired'] == true,
                  revision: '$revision:${r['status']}:${r['proposalVersion']}',
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Lịch sử xử lý',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          itemBuilder: (h) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(historyActions[h['action']] ?? 'Cập nhật yêu cầu'),
            subtitle: Text(
              '${supportHistoryText('${h['note'] ?? ''}')}\n${dateText(h['createdAt'])}',
            ),
          ),
        );
      },
    );
  }
}
