import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/paged_records.dart';
import '../../../shared/widgets/panel.dart';
import '../../../shared/widgets/customer_detail.dart';
import '../../../shared/widgets/remote_attachments.dart';
import '../../auth/presentation/widgets/login_gate.dart';
import 'review_create_screen.dart';

class ReviewsScreen extends StatefulWidget {
  final String? productId;
  const ReviewsScreen({super.key, this.productId});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int revision = 0;
  bool busy = false;
  Future<void> remove(Json row) async {
    final service = StoreScope.of(context).reviewService;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đánh giá?'),
        content: const Text(
          'Đánh giá và ảnh/video sẽ bị xóa. Bạn có thể viết lại khi máy chủ xác nhận xóa thành công.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await service.remove('${row['id']}');
      if (mounted) {
        setState(() => revision++);
        toast(context, 'Đã xóa đánh giá.');
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        service = store.reviewService,
        scope = '${store.api.sessionVersion}';
    return DefaultTabController(
      length: 2,
      initialIndex: widget.productId == null ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trải nghiệm của bạn'),
          bottom: store.loggedIn
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Đánh giá của tôi'),
                    Tab(text: 'Sản phẩm đã nhận'),
                  ],
                )
              : null,
        ),
        body: !store.loggedIn
            ? const LoginGate('Đăng nhập để đánh giá sản phẩm đã mua và nhận.')
            : TabBarView(
                children: [
                  PagedRecords(
                    key: ValueKey('mine:$scope'),
                    refreshToken: revision,
                    load: service.mine,
                    empty: 'Bạn chưa gửi đánh giá.',
                    itemBuilder: (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['productName']} · ${r['variantName']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${r['rating']} sao · ${r['published'] == true ? 'Đang công khai' : 'Không công khai'}',
                            ),
                            Text('${r['title'] ?? ''}'),
                            Text('${r['content'] ?? ''}'),
                            Text(dateText(r['createdAt'])),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => open(
                                    context,
                                    CustomerDetail(
                                      title: 'Đánh giá của bạn',
                                      load: () => service.get('${r['id']}'),
                                      builder: (d, _) => ListView(
                                        padding: const EdgeInsets.all(20),
                                        children: [
                                          Text(
                                            '${d['productName']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          Text('${d['rating']} sao'),
                                          Text('${d['title'] ?? ''}'),
                                          SelectableText(
                                            '${d['content'] ?? ''}',
                                          ),
                                          RemoteAttachments(
                                            objects(d['media']),
                                          ),
                                        ],
                                      ),
                                    ),
                                    account: true,
                                  ),
                                  child: const Text('Xem chi tiết'),
                                ),
                                TextButton(
                                  onPressed: busy ? null : () => remove(r),
                                  child: const Text('Xóa đánh giá'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PagedRecords(
                    key: ValueKey('eligible:$scope'),
                    refreshToken: revision,
                    load: (p) =>
                        service.eligible(p, productId: widget.productId),
                    empty: 'Chưa có sản phẩm đã nhận đủ điều kiện đánh giá.',
                    itemBuilder: (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['productName']} · ${r['variantName']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Đơn ${r['orderCode']} · ${dateText(r['orderedAt'])}',
                            ),
                            if (number(r['reviewCount']) > 0)
                              const Text(
                                'Bạn đã đánh giá sản phẩm này. Xóa đánh giá cũ để viết lại.',
                              )
                            else
                              FilledButton(
                                onPressed: () async {
                                  await open(
                                    context,
                                    ReviewCreateScreen(r),
                                    account: true,
                                  );
                                  if (mounted) setState(() => revision++);
                                },
                                child: const Text('Viết đánh giá'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
