import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/json.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/panel.dart';
import '../domain/store_contact.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> launch(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Show a useful action when no phone/mail/maps app exists. */
    }
    if (context.mounted) {
      toast(
        context,
        'Chưa mở được ứng dụng. Bạn có thể sao chép thông tin bên dưới.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Liên hệ organicfood')),
    body: AsyncView<Json>(
      load: () async {
        try {
          return StoreContact.withDefaults(
            object(
              await StoreScope.of(context).api
                  .request('GET', '/home/content', authenticated: false),
            ),
          );
        } catch (_) {
          return StoreContact.withDefaults({'_loadFailed': true});
        }
      },
      builder: (content) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Thông tin liên hệ',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Thông tin do cửa hàng công bố. Chọn gọi điện, gửi email hoặc xem đường đi để liên hệ.',
          ),
          if (content['_loadFailed'] == true) ...[
            const SizedBox(height: 12),
            const Text(
              'Chưa tải được thông tin cập nhật. Đang hiển thị thông tin liên hệ từ footer cửa hàng.',
            ),
          ],
          const SizedBox(height: 20),
          for (final entry in [
            (
              'Địa chỉ',
              '${content['contactAddress'] ?? ''}',
              Icons.place_outlined,
            ),
            (
              'Điện thoại',
              '${content['contactPhone'] ?? ''}',
              Icons.phone_outlined,
            ),
            ('Email', '${content['contactEmail'] ?? ''}', Icons.email_outlined),
            ('Giờ mở cửa', '${content['openingHours'] ?? ''}', Icons.schedule),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(entry.$3),
                        const SizedBox(width: 10),
                        Text(entry.$1),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      entry.$2.trim().isEmpty
                          ? 'Cửa hàng chưa công bố thông tin này.'
                          : entry.$2,
                    ),
                    if (entry.$2.trim().isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (entry.$1 != 'Giờ mở cửa')
                            TextButton(
                              onPressed: () {
                                final uri = switch (entry.$1) {
                                  'Điện thoại' => Uri(
                                    scheme: 'tel',
                                    path: entry.$2.replaceAll(
                                      RegExp(r'[^+0-9]'),
                                      '',
                                    ),
                                  ),
                                  'Email' => Uri(
                                    scheme: 'mailto',
                                    path: entry.$2,
                                  ),
                                  _ => Uri.https(
                                    'www.google.com',
                                    '/maps/search/',
                                    {'api': '1', 'query': entry.$2},
                                  ),
                                };
                                launch(context, uri);
                              },
                              child: Text(switch (entry.$1) {
                                'Điện thoại' => 'Gọi điện',
                                'Email' => 'Gửi email',
                                _ => 'Xem đường đi',
                              }),
                            ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: entry.$2),
                              );
                              if (context.mounted) {
                                toast(
                                  context,
                                  'Đã sao chép ${entry.$1.toLowerCase()}.',
                                );
                              }
                            },
                            child: const Text('Sao chép'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
