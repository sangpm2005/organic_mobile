import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/paged_records.dart';
import '../../../shared/widgets/panel.dart';
import '../../../shared/widgets/session_boundary.dart';
import '../../auth/presentation/widgets/login_gate.dart';
import '../domain/feedback_labels.dart';
import 'feedback_detail_screen.dart';
import 'widgets/feedback_composer.dart';

class FeedbackListScreen extends StatefulWidget {
  final String? orderId;
  const FeedbackListScreen({super.key, this.orderId});
  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  String? status;
  int revision = 0;
  Future<void> compose() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => SessionBoundary(
          child: Scaffold(
            appBar: AppBar(title: const Text('Gửi phản hồi')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: FeedbackComposer(
                orderId: widget.orderId,
                onSaved: () {},
                onCreated: (id) => Navigator.pop(ctx, id),
                onUncertain: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => revision++);
    if (id != null) {
      await open(context, FeedbackDetailScreen(id), account: true);
    }
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phản hồi & hỗ trợ'),
        actions: [
          if (store.loggedIn)
            IconButton(
              onPressed: compose,
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'Gửi phản hồi',
            ),
        ],
      ),
      body: !store.loggedIn
          ? const LoginGate(
              'Đăng nhập để gửi phản hồi và trao đổi với cửa hàng.',
            )
          : PagedRecords(
              key: ValueKey('${store.api.sessionVersion}:$status'),
              refreshToken: revision,
              load: (p) => store.feedbackService.list(
                p,
                orderId: widget.orderId,
                status: status,
              ),
              empty: 'Chưa có phản hồi.',
              header: [
                DropdownButtonFormField<String>(
                  initialValue: status ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tất cả')),
                    ...feedbackStates.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v == '' ? null : v),
                ),
                const SizedBox(height: 16),
              ],
              itemBuilder: (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () async {
                    await open(
                      context,
                      FeedbackDetailScreen('${f['id']}'),
                      account: true,
                    );
                    if (mounted) setState(() => revision++);
                  },
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${f['subject']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${f['feedbackCode']} · ${feedbackStates[f['status']] ?? f['status']}',
                        ),
                        if (object(f['order'])['orderCode'] != null)
                          Text('Đơn ${object(f['order'])['orderCode']}'),
                        Text(dateText(f['updatedAt'] ?? f['createdAt'])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
