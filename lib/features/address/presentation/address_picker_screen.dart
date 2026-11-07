import 'package:flutter/material.dart';

import '../../../shared/navigation/navigation.dart';
import '../data/address_directory.dart';
import '../domain/vietnam_address.dart';
import 'widgets/structured_address_fields.dart';

class AddressPickerScreen extends StatefulWidget {
  final String initialAddress;
  const AddressPickerScreen({super.key, this.initialAddress = ''});
  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final form = GlobalKey<FormState>();
  VietnamAddresses? directory;
  AddressDraft value = const AddressDraft();
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await AddressDirectory.load();
      if (!mounted) return;
      setState(() {
        directory = data;
        value = data.fromShipping(widget.initialAddress);
      });
    } catch (_) {
      if (mounted) {
        toast(context, 'Chưa tải được danh sách địa chỉ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void accept() {
    if (directory == null || !form.currentState!.validate()) return;
    try {
      Navigator.pop(context, directory!.shipping(value));
    } catch (error) {
      toast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn địa chỉ giao hàng')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : directory == null
        ? Center(
            child: TextButton(
              onPressed: load,
              child: const Text('Tải lại danh sách địa chỉ'),
            ),
          )
        : Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                if (widget.initialAddress.isNotEmpty && value.wardCode.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Text(
                      'Hãy chọn lại tỉnh/thành phố, phường/xã và kiểm tra số nhà, tên đường.',
                    ),
                  ),
                StructuredAddressFields(
                  directory: directory!,
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('address.confirm'),
                  onPressed: accept,
                  child: const Text('Dùng địa chỉ này'),
                ),
              ],
            ),
          ),
  );
}
