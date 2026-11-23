import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/navigation/navigation.dart';

import '../../../../core/utils/json.dart';
import '../../../../shared/state/store_scope.dart';

class DeliveryLocationPicker extends StatefulWidget {
  final String address;
  const DeliveryLocationPicker({super.key, required this.address});
  @override
  State<DeliveryLocationPicker> createState() => _DeliveryLocationPickerState();
}

class _DeliveryLocationPickerState extends State<DeliveryLocationPicker> {
  late final input = TextEditingController(text: widget.address);
  List<Json> results = [];
  bool busy = false;
  String? error;
  Future<void> find() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    final repository = StoreScope.of(context).checkout;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final found = await repository.resolve(text);
      if (mounted) {
        setState(() {
          results = found;
          if (found.isEmpty) {
            error = 'Chưa tìm thấy. Hãy nhập địa chỉ cụ thể hơn.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác nhận vị trí giao hàng')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: input,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ, liên kết Google Maps hoặc tọa độ',
            helperText: 'Ví dụ tọa độ: 10.7799129, 106.699902',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : find,
          child: Text(busy ? 'Đang tìm…' : 'Tìm vị trí'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final place in results) ...[
          TextButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Xem vị trí trên bản đồ'),
            onPressed: () async {
              final uri = Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': '${place['latitude']},${place['longitude']}',
              });
              try {
                if (await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {}
              if (context.mounted) {
                toast(context, 'Chưa mở được bản đồ. Vui lòng thử lại.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text('${place['label']}'),
            subtitle: Text(
              place['precise'] == true
                  ? 'Vị trí chi tiết'
                  : 'Vị trí gần đúng — hãy kiểm tra địa chỉ',
            ),
            onTap: () => Navigator.pop(context, place),
          ),
        ],
      ],
    ),
  );
}
