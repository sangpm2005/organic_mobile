import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/widgets/remote_attachments.dart';

class ProductReviews extends StatefulWidget {
  final String productId;
  final int revision;
  const ProductReviews(this.productId, {super.key, this.revision = 0});
  @override
  State<ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviews> {
  List<Json> rows = [];
  Json summary = {};
  int page = -1, total = 0;
  int? rating;
  String sort = 'newest';
  String? error;
  bool busy = false, initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      load(reset: true);
    }
  }

  @override
  void didUpdateWidget(covariant ProductReviews old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final service = StoreScope.of(context).reviewService;
    try {
      final next = reset ? 0 : page + 1;
      final data = await service.published(
            widget.productId,
            next,
            rating: rating,
            sort: sort,
          ),
          result = object(data['reviews']);
      if (mounted) {
        setState(() {
          summary = object(data['summary']);
          rows = reset ? pageItems(result) : [...rows, ...pageItems(result)];
          page = next;
          total = number(result['totalElements']).toInt();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in objects(summary['distribution']))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 52, child: Text('${item['rating']} sao')),
              Expanded(
                child: LinearProgressIndicator(
                  value: number(summary['totalReviews']) <= 0
                      ? 0
                      : (number(item['count']) /
                                number(summary['totalReviews']))
                            .clamp(0, 1),
                ),
              ),
              const SizedBox(width: 12),
              Text('${item['count']}'),
            ],
          ),
        ),
      if (objects(summary['distribution']).isNotEmpty)
        const SizedBox(height: 18),
      DropdownButtonFormField<int>(
        initialValue: rating ?? 0,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(labelText: 'Lọc theo số sao'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Tất cả đánh giá')),
          for (var i = 5; i >= 1; i--)
            DropdownMenuItem(value: i, child: Text('$i sao')),
        ],
        onChanged: busy
            ? null
            : (v) {
                setState(() => rating = v == 0 ? null : v);
                load(reset: true);
              },
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: sort,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(labelText: 'Sắp xếp đánh giá'),
        items: const [
          DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
          DropdownMenuItem(value: 'highest', child: Text('Điểm cao nhất')),
          DropdownMenuItem(value: 'lowest', child: Text('Điểm thấp nhất')),
        ],
        onChanged: busy
            ? null
            : (v) {
                setState(() => sort = v!);
                load(reset: true);
              },
      ),
      const SizedBox(height: 12),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r['reviewerName'] ?? 'Khách hàng'} · ${r['rating']} sao',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (r['verifiedPurchase'] == true)
                const Text('Đã mua hàng', style: TextStyle(fontSize: 11)),
              Text('${r['title'] ?? ''}'),
              Text('${r['content'] ?? ''}'),
              Text(
                dateText(r['createdAt']),
                style: const TextStyle(fontSize: 11),
              ),
              RemoteAttachments(objects(r['media']), account: false),
              const Divider(),
            ],
          ),
        ),
      if (!busy && error == null && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Chưa có đánh giá phù hợp.'),
        ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (!busy)
        TextButton(
          onPressed: () => load(reset: error != null || rows.length >= total),
          child: Text(
            error != null
                ? 'Thử lại'
                : rows.length < total
                ? 'Xem thêm đánh giá'
                : 'Cập nhật đánh giá',
          ),
        ),
    ],
  );
}
