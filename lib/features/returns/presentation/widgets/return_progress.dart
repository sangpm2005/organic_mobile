import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/widgets/panel.dart';
import '../../../../shared/widgets/paged_records.dart';
import '../../../orders/presentation/order_screen.dart';
import '../../domain/return_labels.dart';

class ReturnProgress extends StatefulWidget {
  final String id;
  final bool returnRequired;
  final Object? revision;
  const ReturnProgress(
    this.id, {
    super.key,
    required this.returnRequired,
    this.revision,
  });
  @override
  State<ReturnProgress> createState() => _ReturnProgressState();
}

class _ReturnProgressState extends State<ReturnProgress> {
  Json? execution, progress;
  String? error;
  bool busy = false;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      load();
    }
  }

  @override
  void didUpdateWidget(covariant ReturnProgress old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) load();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    final service = StoreScope.of(context).returnsService;
    try {
      final result = await service.execution(widget.id);
      final received = widget.returnRequired
          ? await service.progress(widget.id)
          : null;
      if (mounted) {
        setState(() {
          execution = result;
          progress = received;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = execution, totals = object(progress?['totals']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiến độ thực hiện',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextButton(
            onPressed: busy ? null : load,
            child: Text(busy ? 'Đang cập nhật…' : 'Cập nhật tiến độ'),
          ),
          if (ex != null) ...[
            Text(
              'Tiền hoàn trong phương án: ${money(ex['approvedRefundAmount'])}',
            ),
            Text('Đã hoàn thành công: ${money(ex['refundedAmount'])}'),
            Text('Đang xử lý hoàn: ${money(ex['pendingRefundAmount'])}'),
            if (object(ex['automaticRefund'])['message'] != null)
              Text('${object(ex['automaticRefund'])['message']}'),
            for (final r in objects(ex['refunds']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['refundCode']} · ${refundStates[r['status']] ?? r['status']}',
                    ),
                    Text('${r['amount']} ${r['currency'] ?? 'VND'}'),
                    if (r['bankName'] != null)
                      Text(
                        '${r['bankName']} · ${r['maskedAccountNumber'] ?? ''}',
                      ),
                    if (r['processedAt'] != null)
                      Text('Cập nhật: ${dateText(r['processedAt'])}'),
                    if (r['failureReason'] != null)
                      Text('${r['failureReason']}'),
                  ],
                ),
              ),
            if (object(ex['replacementOrder'])['id'] != null)
              TextButton.icon(
                onPressed: () => open(
                  context,
                  OrderScreen('${object(ex['replacementOrder'])['id']}'),
                  account: true,
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(
                  'Theo dõi đơn đổi ${object(ex['replacementOrder'])['orderCode']}',
                ),
              ),
            for (final blocker in ex['blockers'] as List? ?? [])
              Text('$blocker'),
            if (ex['completedAt'] != null)
              Text('Hoàn tất hồ sơ: ${dateText(ex['completedAt'])}'),
          ],
          if (progress != null) ...[
            const Divider(),
            Text(
              'Cửa hàng đã nhận: ${totals['receivedQuantity'] ?? 0}/${totals['approvedReturnQuantity'] ?? 0} sản phẩm',
            ),
            Text(
              'Còn chờ nhận: ${totals['remainingToReceive'] ?? 0} · Chưa kiểm tra: ${totals['uninspectedQuantity'] ?? 0}',
            ),
            Text(
              totals['warehouseComplete'] == true
                  ? 'Đã hoàn tất xử lý hàng thu hồi.'
                  : 'Đang xử lý hàng thu hồi.',
            ),
            TextButton(
              onPressed: () => open(
                context,
                Scaffold(
                  appBar: AppBar(
                    title: const Text('Các lần cửa hàng nhận hàng'),
                  ),
                  body: PagedRecords(
                    load: (p) =>
                        StoreScope.of(context).returnsService
                            .receipts(widget.id, p),
                    empty: 'Chưa ghi nhận lần nhận hàng.',
                    itemBuilder: (r) => ListTile(
                      title: Text('${r['productName']} · ${r['variantName']}'),
                      subtitle: Text(
                        'Đã nhận ${r['receivedQuantity']} · Đạt ${r['passedQuantity']} · Không đạt ${r['failedQuantity']}\n${dateText(r['receivedAt'])}\n${r['receiptNote'] ?? ''}',
                      ),
                    ),
                  ),
                ),
                account: true,
              ),
              child: const Text('Xem lịch sử nhận hàng'),
            ),
          ],
        ],
      ),
    );
  }
}
