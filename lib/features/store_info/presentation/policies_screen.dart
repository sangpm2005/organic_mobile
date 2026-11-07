import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/json.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/panel.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chính sách & hướng dẫn')),
    body: AsyncView<List<Json>>(
      load: () async => objects(
        jsonDecode(
          await rootBundle.loadString('assets/data/customer-policies.json'),
        ),
      ),
      builder: (pages) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final page in pages)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text('${page['title']}'),
              subtitle: Text('${page['summary']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(context, _PolicyDetail(page)),
            ),
        ],
      ),
    ),
  );
}

class _PolicyDetail extends StatelessWidget {
  final Json page;
  const _PolicyDetail(this.page);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${page['title']}')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          '${page['summary']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 22),
        for (final section in objects(page['sections']))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${section['title']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final text in section['paragraphs'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('$text'),
                    ),
                  for (final text in section['bullets'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('• $text'),
                    ),
                  for (final (i, text)
                      in (section['steps'] as List? ?? []).indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('${i + 1}. $text'),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
