import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/json.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/panel.dart';
import '../../catalog/presentation/catalog_screen.dart';

class StoreRecordsScreen extends StatelessWidget {
  final bool certificates;
  const StoreRecordsScreen({super.key, this.certificates = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(certificates ? 'Hồ sơ chứng nhận' : 'Thông tin nguồn gốc'),
    ),
    body: AsyncView<List<Json>>(
      load: () async => objects(
        await StoreScope.of(context).api.request(
          'GET',
          certificates ? '/home/certifications' : '/home/origins',
          authenticated: false,
        ),
      ),
      builder: (rows) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            certificates
                ? 'Chứng nhận được công bố'
                : 'Vùng sản xuất & nhà cung cấp',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Mở từng hồ sơ để xem chi tiết. Thông tin áp dụng cho mỗi sản phẩm được hiển thị tại trang chi tiết sản phẩm.',
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty) const Text('Chưa có hồ sơ được công bố.'),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    certificates ? Icons.verified_outlined : Icons.grass,
                  ),
                  title: Text('${row['name'] ?? ''}'),
                  subtitle: Text(
                    certificates
                        ? '${row['issuingOrganization'] ?? ''}'
                        : [
                            row['region'],
                            row['country'],
                          ].where((v) => v != null).join(', '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    context,
                    _RecordDetail(row, certificates: certificates),
                  ),
                ),
              ),
            ),
          OutlinedButton(
            onPressed: () => open(context, const CatalogScreen()),
            child: const Text('Xem sản phẩm và hồ sơ áp dụng'),
          ),
        ],
      ),
    ),
  );
}

class _RecordDetail extends StatelessWidget {
  final Json row;
  final bool certificates;
  const _RecordDetail(this.row, {required this.certificates});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết hồ sơ')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          '${row['name'] ?? ''}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry
                  in (certificates
                          ? {
                              'Số chứng nhận': row['number'],
                              'Tổ chức cấp': row['issuingOrganization'],
                              'Ngày cấp': row['issuedAt'],
                              'Hết hạn': row['expiresAt'],
                            }
                          : {
                              'Quốc gia': row['country'],
                              'Vùng sản xuất': row['region'],
                              'Nhà sản xuất': row['producerName'],
                              'Địa chỉ': row['address'],
                            })
                      .entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('${entry.key}: ${entry.value ?? 'Chưa công bố'}'),
                ),
              if ('${row['description'] ?? ''}'.isNotEmpty)
                Text('${row['description']}'),
            ],
          ),
        ),
        if (Uri.tryParse('${row['documentUrl']}') case final uri?
            when uri.scheme == 'https' &&
                uri.host.isNotEmpty &&
                uri.userInfo.isEmpty)
          TextButton.icon(
            onPressed: () async {
              try {
                if (await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {
                /* Report unavailable viewer. */
              }
              if (context.mounted) {
                toast(context, 'Chưa mở được tài liệu chứng nhận.');
              }
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('Mở tài liệu chứng nhận'),
          ),
      ],
    ),
  );
}
