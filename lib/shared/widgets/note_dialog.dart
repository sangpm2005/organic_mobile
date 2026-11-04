import 'package:flutter/material.dart';

Future<String?> askNote(
  BuildContext context,
  String title, {
  String? description,
  bool required = true,
  int maxLength = 5000,
}) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(description),
                ),
              TextFormField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: maxLength,
                decoration: InputDecoration(
                  labelText: required
                      ? 'Nội dung / lý do *'
                      : 'Ghi chú (không bắt buộc)',
                ),
                validator: (v) => required && (v?.trim().isEmpty ?? true)
                    ? 'Vui lòng nhập nội dung.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  // Dispose after the dialog route's exit animation has finished.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}
