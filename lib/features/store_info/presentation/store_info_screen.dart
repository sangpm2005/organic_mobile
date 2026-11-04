import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/json.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/panel.dart';
import '../../../shared/navigation/navigation.dart';

class StoreInfoScreen extends StatelessWidget {
  const StoreInfoScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Về organicfood')),
    body: AsyncView<Json>(
      load: () async => object(
        await StoreScope.of(context).api
            .request('GET', '/home/content', authenticated: false),
      ),
      builder: (c) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'organicfood',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text('${c['headline'] ?? ''}'),
          const SizedBox(height: 16),
          Text('${c['introduction'] ?? ''}'),
          if (c['contactAddress'] != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text('${c['contactAddress']}'),
            ),
          if (c['openingHours'] != null)
            Text('Giờ mở cửa: ${c['openingHours']}'),
          if (RegExp(r'^[+0-9 ()-]{8,30}$')
              .hasMatch('${c['contactPhone'] ?? ''}'))
            TextButton.icon(
              onPressed: () async {
                if (!await launchUrl(
                      Uri(scheme: 'tel', path: '${c['contactPhone']}'),
                    ) &&
                    context.mounted) {
                  toast(context, 'Chưa mở được ứng dụng điện thoại.');
                }
              },
              icon: const Icon(Icons.phone_outlined),
              label: Text('${c['contactPhone']}'),
            ),
          if ('${c['contactEmail'] ?? ''}'.contains('@'))
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri(scheme: 'mailto', path: '${c['contactEmail']}'),
              ),
              icon: const Icon(Icons.email_outlined),
              label: Text('${c['contactEmail']}'),
            ),
          for (final h in objects(c['highlights']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${h['title']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${h['description']}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Câu hỏi thường gặp',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final f in objects(c['faqs']))
            ExpansionTile(
              title: Text('${f['question']}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${f['answer']}'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
