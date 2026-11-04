import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/paged_records.dart';
import '../../../shared/widgets/panel.dart';
import '../../auth/presentation/widgets/login_gate.dart';
import '../../orders/presentation/orders_screen.dart';
import '../domain/return_labels.dart';
import 'return_detail_screen.dart';
import 'return_create_screen.dart';

class ReturnsScreen extends StatefulWidget {
  final String? orderId;
  const ReturnsScreen({super.key, this.orderId});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  String? status;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        pending = object(store.pendingReturn?['payload']);
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi trả & hoàn tiền')),
      body: !store.loggedIn
          ? const LoginGate('Đăng nhập để theo dõi yêu cầu đổi trả.')
          : PagedRecords(
              key: ValueKey('${store.api.sessionVersion}:$status'),
              refreshToken: revision,
              load: (p) => store.returnsService.list(
                p,
                orderId: widget.orderId,
                status: status,
              ),
              empty: 'Chưa có yêu cầu đổi trả.',
              header: [
                if (store.pendingReturn != null)
                  TextButton(
                    onPressed: () => open(
                      context,
                      ReturnCreateScreen('${pending['orderId']}'),
                      account: true,
                    ),
                    child: const Text('Kiểm tra yêu cầu chưa rõ kết quả'),
                  ),
                FilledButton.icon(
                  onPressed: () => widget.orderId != null
                      ? open(
                          context,
                          ReturnCreateScreen(widget.orderId!),
                          account: true,
                        )
                      : open(
                          context,
                          Scaffold(
                            appBar: AppBar(
                              title: const Text('Chọn đơn hàng cần hỗ trợ'),
                            ),
                            body: const OrdersScreen(),
                          ),
                          account: true,
                        ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    widget.orderId != null
                        ? 'Gửi yêu cầu cho đơn này'
                        : 'Chọn đơn hàng để gửi yêu cầu',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tất cả')),
                    ...returnStates.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v == '' ? null : v),
                ),
                const SizedBox(height: 16),
              ],
              itemBuilder: (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () async {
                    await open(
                      context,
                      ReturnDetailScreen('${r['id']}'),
                      account: true,
                    );
                    if (mounted) setState(() => revision++);
                  },
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['requestCode']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          returnTypes[r['requestType']] ??
                              '${r['requestType']}',
                        ),
                        Text(returnStates[r['status']] ?? '${r['status']}'),
                        Text(
                          'Đơn ${object(r['order'])['orderCode']} · ${dateText(r['requestedAt'])}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
