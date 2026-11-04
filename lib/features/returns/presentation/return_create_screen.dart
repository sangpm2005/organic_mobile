import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/media/upload_file.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/attachment_picker.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/session_boundary.dart';
import '../domain/return_labels.dart';
import 'return_detail_screen.dart';

class ReturnCreateScreen extends StatefulWidget {
  final String orderId;
  const ReturnCreateScreen(this.orderId, {super.key});
  @override
  State<ReturnCreateScreen> createState() => _ReturnCreateScreenState();
}

class _ReturnCreateScreenState extends State<ReturnCreateScreen> {
  final form = GlobalKey<FormState>(), description = TextEditingController();
  final Map<String, TextEditingController> quantities = {};
  String type = 'return_refund', reason = 'damaged';
  List<UploadFile> files = [];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    description.dispose();
    for (final c in quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> send(Json eligibility) async {
    final store = StoreScope.of(context);
    if (busy) return;
    final pending = store.pendingReturn;
    if (pending == null && !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Json? payload;
      if (pending == null) {
        final rows = objects(eligibility['items']);
        final selected = rows
            .where(
              (r) =>
                  (int.tryParse(
                        quantities['${r['orderDetailId']}']?.text ?? '0',
                      ) ??
                      0) >
                  0,
            )
            .toList();
        if (selected.isEmpty) {
          throw const ApiException(
            'Vui lòng chọn ít nhất một sản phẩm cần hỗ trợ.',
          );
        }
        payload = {
          'orderId': widget.orderId,
          'requestType': type,
          'reason': reason,
          'description': description.text.trim(),
          'items': selected
              .map(
                (r) => {
                  'orderDetailId': r['orderDetailId'],
                  'quantity': int.parse(
                    quantities['${r['orderDetailId']}']!.text,
                  ),
                  'reason': reason,
                },
              )
              .toList(),
        };
      }
      final result = await store.submitReturn(
        payload: payload,
        files: pending == null ? files : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionBoundary(
            child: ReturnDetailScreen('${object(result['request'])['id']}'),
          ),
        ),
      );
      toast(
        context,
        'Đã gửi yêu cầu. Cửa hàng sẽ xét duyệt trước khi thực hiện.',
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), pending = store.pendingReturn;
    final saved = object(pending?['payload']);
    final other = pending != null && saved['orderId'] != widget.orderId;
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu đổi trả')),
      body: other
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Có một yêu cầu đang chờ xác nhận. Vui lòng kiểm tra trước khi tạo yêu cầu khác.',
                    ),
                    TextButton(
                      onPressed: () => open(
                        context,
                        ReturnCreateScreen('${saved['orderId']}'),
                        account: true,
                      ),
                      child: const Text('Kiểm tra yêu cầu đang chờ'),
                    ),
                  ],
                ),
              ),
            )
          : pending != null
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Chưa rõ kết quả lần gửi trước. Nội dung, ảnh và mã yêu cầu được giữ nguyên để kiểm tra lại, tránh tạo trùng.',
                ),
                Text(
                  '${returnTypes[saved['requestType']] ?? ''}\n${saved['description'] ?? ''}',
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : () => send({}),
                  child: Text(
                    busy ? 'Đang kiểm tra…' : 'Kiểm tra lại yêu cầu này',
                  ),
                ),
              ],
            )
          : AsyncView<Json>(
              load: () => store.returnsService.eligible(widget.orderId),
              builder: (eligible) {
                final rows = objects(eligible['items']);
                final cancelled =
                    object(eligible['order'])['status'] == 'cancelled';
                if (cancelled) type = 'refund';
                for (final r in rows) {
                  quantities.putIfAbsent(
                    '${r['orderDetailId']}',
                    () => TextEditingController(text: '0'),
                  );
                }
                return Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Đơn ${object(eligible['order'])['orderCode'] ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (eligible['canSubmit'] != true)
                        Text(
                          '${eligible['unavailableReason'] ?? 'Đơn chưa đủ điều kiện đổi trả.'}',
                        )
                      else ...[
                        const Text(
                          'Yêu cầu sẽ được cửa hàng xét duyệt; gửi yêu cầu chưa có nghĩa đã được hoàn tiền hoặc giao hàng đổi.',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Hình thức hỗ trợ',
                          ),
                          items: returnTypes.entries
                              .where((e) => !cancelled || e.key == 'refund')
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => type = v!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: reason,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Lý do'),
                          items: returnReasons.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => reason = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: description,
                          enabled: !busy,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: 5000,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả chi tiết *',
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Vui lòng mô tả vấn đề.'
                              : null,
                        ),
                        AttachmentPicker(
                          files: files,
                          onChanged: (v) => setState(() => files = v),
                          imagesOnly: true,
                          enabled: !busy,
                        ),
                        for (final r in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['productName']} · ${r['variantName']}',
                                ),
                                Text(
                                  'Còn được yêu cầu: ${r['availableQuantity']}',
                                ),
                                if (r['policyDeadline'] != null)
                                  Text(
                                    'Thời hạn theo chính sách: ${dateText(r['policyDeadline'])}',
                                  ),
                                if (r['policyAssessment'] != null)
                                  Text(
                                    '${r['policyAssessment']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                TextFormField(
                                  key: ValueKey(
                                    'return.quantity.${r['orderDetailId']}',
                                  ),
                                  controller:
                                      quantities['${r['orderDetailId']}'],
                                  enabled:
                                      !busy &&
                                      number(r['availableQuantity']) > 0,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Số lượng cần hỗ trợ',
                                  ),
                                  validator: (v) {
                                    final q = int.tryParse(v ?? '');
                                    return q == null ||
                                            q < 0 ||
                                            q > number(r['availableQuantity'])
                                        ? 'Nhập số nguyên từ 0 đến ${r['availableQuantity']}.'
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        FilledButton(
                          onPressed: busy ? null : () => send(eligible),
                          child: Text(
                            busy ? 'Đang gửi…' : 'Gửi yêu cầu xét duyệt',
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
