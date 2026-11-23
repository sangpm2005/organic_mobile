import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import 'widgets/avatar_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in ['fullName', 'phoneNumber', 'email', 'dateOfBirth'])
      k: TextEditingController(),
  };
  bool initialized = false, busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final store = StoreScope.of(context);
      final p = store.profile ?? store.user;
      for (final e in fields.entries) {
        e.value.text = '${p?[e.key] ?? ''}';
      }
      initialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> chooseBirthday() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final current = DateTime.tryParse(fields['dateOfBirth']!.text);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate:
          current != null && !current.isAfter(now) && current.year >= 1900
          ? current
          : DateTime(now.year - 20, now.month, now.day),
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null && mounted && !busy) {
      fields['dateOfBirth']!.text = picked.toIso8601String().substring(0, 10);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    final store = StoreScope.of(context);
    try {
      await store.api.request(
        'PUT',
        '/customers/me',
        body: {
          for (final e in fields.entries)
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        },
      );
      await store.refreshAccount(force: true);
      if (mounted) {
        toast(context, 'Đã cập nhật thông tin.');
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
    appBar: AppBar(title: const Text('Thông tin cá nhân')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const AvatarEditor(),
          for (final e in {
            'fullName': 'Họ và tên',
            'phoneNumber': 'Số điện thoại',
            'email': 'Email',
            'dateOfBirth': 'Ngày sinh (yyyy-MM-dd)',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('profile.${e.key}'),
                controller: fields[e.key],
                enabled: !busy,
                keyboardType: e.key == 'phoneNumber'
                    ? TextInputType.phone
                    : e.key == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                readOnly: e.key == 'dateOfBirth',
                onTap: e.key == 'dateOfBirth' ? chooseBirthday : null,
                decoration: InputDecoration(
                  labelText: e.value,
                  suffixIcon: e.key == 'dateOfBirth'
                      ? IconButton(
                          tooltip: 'Chọn ngày sinh',
                          onPressed: busy ? null : chooseBirthday,
                          icon: const Icon(Icons.calendar_month_outlined),
                        )
                      : null,
                ),
                validator: (v) {
                  if (e.key == 'fullName' && (v == null || v.trim().isEmpty)) {
                    return 'Nhập họ và tên.';
                  }
                  if (e.key == 'email' &&
                      (v ?? '').isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!)) {
                    return 'Email chưa hợp lệ.';
                  }
                  if (e.key == 'phoneNumber' &&
                      !RegExp(r'^\+?[0-9]{9,10}$').hasMatch((v ?? '').trim())) {
                    return 'Nhập số điện thoại có 10 chữ số.';
                  }
                  if (e.key == 'dateOfBirth' &&
                      (v ?? '').isNotEmpty &&
                      (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v!) ||
                          DateTime.tryParse(v)
                                  ?.toIso8601String()
                                  .substring(0, 10) !=
                              v ||
                          DateTime.parse(v).isAfter(DateTime.now()))) {
                    return 'Nhập ngày theo yyyy-MM-dd.';
                  }
                  return null;
                },
              ),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Lưu thông tin'),
          ),
        ],
      ),
    ),
  );
}
