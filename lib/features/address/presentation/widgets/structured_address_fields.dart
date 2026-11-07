import 'package:flutter/material.dart';

import '../../domain/vietnam_address.dart';
import 'searchable_address_field.dart';

class StructuredAddressFields extends StatefulWidget {
  final VietnamAddresses directory;
  final AddressDraft value;
  final ValueChanged<AddressDraft> onChanged;
  final bool enabled;
  const StructuredAddressFields({
    super.key,
    required this.directory,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  State<StructuredAddressFields> createState() =>
      _StructuredAddressFieldsState();
}

class _StructuredAddressFieldsState extends State<StructuredAddressFields> {
  final search = TextEditingController();
  late final street = TextEditingController(text: widget.value.street);
  String query = '';

  @override
  void didUpdateWidget(StructuredAddressFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (street.text != widget.value.street) street.text = widget.value.street;
  }

  void change(AddressDraft value) {
    search.clear();
    setState(() => query = '');
    widget.onChanged(value);
  }

  @override
  void dispose() {
    search.dispose();
    street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value, directory = widget.directory;
    final suggestions = query.trim().length >= 2
        ? directory.search(query)
        : <AddressWard>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('address.search'),
          controller: search,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Tìm nhanh địa chỉ',
            hintText: 'Tên phường/xã, tỉnh/thành phố hoặc tên cũ',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (text) => setState(() => query = text),
        ),
        if (query.trim().length >= 2) ...[
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa tìm thấy. Thử tên đầy đủ hoặc chọn trong danh sách bên dưới.',
              ),
            ),
          for (final ward in suggestions)
            ListTile(
              key: ValueKey('address.suggestion.${ward.code}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.place_outlined),
              title: Text(ward.name),
              subtitle: Text(ward.province.name),
              onTap: !widget.enabled
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      change(
                        value.copyWith(
                          provinceCode: ward.province.code,
                          wardCode: ward.code,
                        ),
                      );
                    },
            ),
        ],
        const SizedBox(height: 18),
        SearchableAddressField(
          id: 'address.province',
          label: 'Tỉnh / Thành phố',
          value: value.provinceCode,
          choices: [
            for (final province in directory.provinces)
              AddressChoice(province.code, province.name),
          ],
          enabled: widget.enabled,
          onChanged: (code) =>
              change(value.copyWith(provinceCode: code, wardCode: '')),
        ),
        SearchableAddressField(
          id: 'address.ward',
          label: 'Phường / Xã',
          value: value.wardCode,
          choices: [
            for (final ward in directory.wardsOf(value.provinceCode))
              AddressChoice(
                ward.code,
                ward.name,
                searchText: '${ward.title} ${ward.search}',
              ),
          ],
          enabled:
              widget.enabled && directory.province(value.provinceCode) != null,
          onChanged: (code) => change(value.copyWith(wardCode: code)),
        ),
        TextFormField(
          key: const ValueKey('address.streetAddress'),
          controller: street,
          enabled: widget.enabled,
          maxLines: 2,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Số nhà, tên đường',
            hintText: 'Ví dụ: 36 Trịnh Đình Trọng',
          ),
          onChanged: (text) => widget.onChanged(value.copyWith(street: text)),
          validator: (text) => text == null || text.trim().isEmpty
              ? 'Vui lòng nhập số nhà, tên đường.'
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          'Dữ liệu: tinhthanhpho.com · CC BY 4.0',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
