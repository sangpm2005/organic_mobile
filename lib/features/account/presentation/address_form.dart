import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/address/data/address_directory.dart';
import 'package:organic_mobile/features/address/domain/vietnam_address.dart';
import 'package:organic_mobile/features/address/presentation/widgets/structured_address_fields.dart';
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
    for (final k in ['label', 'receiverName', 'receiverPhone'])
      k: TextEditingController(text: '${widget.address?[k] ?? ''}'),
  };
  late bool isDefault = widget.address?['isDefault'] == true;
  bool busy = false;
  VietnamAddresses? directory;
  AddressDraft value = const AddressDraft();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    setState(() => loading = true);
    try {
      final data = await AddressDirectory.load();
      if (mounted) {
        setState(() {
          directory = data;
          value = data.fromSaved(widget.address ?? {});
        });
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'Chưa tải được danh sách địa chỉ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || directory == null || !form.currentState!.validate()) {
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
          ...directory!.profileFields(value, previous: widget.address),
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
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('address.${e.key}'),
                controller: fields[e.key],
                enabled: !busy,
                keyboardType: e.key == 'receiverPhone'
                    ? TextInputType.phone
                    : TextInputType.text,
                decoration: InputDecoration(labelText: e.value),
                validator: (text) {
                  final v = text?.trim() ?? '';
                  if (e.key != 'label' && v.isEmpty) {
                    return 'Vui lòng nhập ${e.value.toLowerCase()}.';
                  }
                  if (v.length > 255) return 'Nội dung tối đa 255 ký tự.';
                  if (e.key == 'receiverPhone' &&
                      !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v)) {
                    return 'Số điện thoại phải có từ 9 đến 15 chữ số.';
                  }
                  return null;
                },
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (directory == null)
            TextButton(
              onPressed: loadAddresses,
              child: const Text('Tải lại danh sách địa chỉ'),
            )
          else
            StructuredAddressFields(
              directory: directory!,
              value: value,
              enabled: !busy,
              onChanged: (next) => setState(() => value = next),
            ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đặt làm địa chỉ mặc định'),
            value: isDefault,
            onChanged: busy ? null : (v) => setState(() => isDefault = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy || directory == null ? null : save,
            child: const Text('Lưu địa chỉ'),
          ),
        ],
      ),
    ),
  );
}
