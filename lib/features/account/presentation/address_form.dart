import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

class AddressForm extends StatefulWidget {
  final Json? address;
  const AddressForm({super.key, this.address});
  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final k in [
      'label',
      'receiverName',
      'receiverPhone',
      'province',
      'district',
      'ward',
      'streetAddress',
    ])
      k: TextEditingController(text: '${widget.address?[k] ?? ''}'),
  };
  late bool isDefault = widget.address?['isDefault'] == true;
  bool busy = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    final store = StoreScope.of(context);
    try {
      final id = widget.address?['id'];
      await store.api.request(
        id == null ? 'POST' : 'PUT',
        '/customers/me/addresses${id == null ? '' : '/$id'}',
        body: {
          for (final e in fields.entries) e.key: e.value.text.trim(),
          'isDefault': isDefault,
        },
      );
      await store.refreshAccount(force: true);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        toast(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.address == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          for (final e in {
            'label': 'Tên địa chỉ (Nhà, Cơ quan…)',
            'receiverName': 'Người nhận',
            'receiverPhone': 'Số điện thoại',
            'province': 'Tỉnh / Thành phố',
            'district': 'Quận / Huyện',
            'ward': 'Phường / Xã',
            'streetAddress': 'Số nhà, tên đường',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('address.${e.key}'),
                controller: fields[e.key],
                enabled: !busy,
                decoration: InputDecoration(labelText: e.value),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập ${e.value.toLowerCase()}.'
                    : null,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đặt làm địa chỉ mặc định'),
            value: isDefault,
            onChanged: busy ? null : (v) => setState(() => isDefault = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Lưu địa chỉ'),
          ),
        ],
      ),
    ),
  );
}
