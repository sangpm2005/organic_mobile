import 'package:flutter/material.dart';

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
      final isUrl = Uri.tryParse(text)?.hasScheme == true;
      final found = isUrl
          ? [await repository.fromMap(text)]
          : await repository.locations(text);
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
            labelText: 'Địa chỉ hoặc liên kết Google Maps',
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
        for (final place in results)
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
    ),
  );
}
