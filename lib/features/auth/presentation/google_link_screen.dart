import 'package:flutter/material.dart';

import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';

class GoogleLinkScreen extends StatefulWidget {
  const GoogleLinkScreen({super.key});
  @override
  State<GoogleLinkScreen> createState() => _GoogleLinkScreenState();
}

class _GoogleLinkScreenState extends State<GoogleLinkScreen> {
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> link() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final linked = await StoreScope.of(context)
          .linkGoogle(password.text, isActive: () => mounted);
      if (mounted && linked) {
        toast(
          context,
          'Đã liên kết Google. Lần sau bạn có thể đăng nhập bằng Google.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Liên kết Google')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Chọn tài khoản Google có email trùng với email hồ sơ của bạn. Giỏ hàng, đơn hàng và điểm thưởng vẫn thuộc tài khoản hiện tại.',
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('google.currentPassword'),
          controller: password,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu hiện tại (nếu có)',
          ),
          onSubmitted: (_) => link(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nhập mật khẩu organicfood nếu tài khoản đã có mật khẩu. Không nhập mật khẩu Google.',
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('google.link'),
          onPressed: busy ? null : link,
          icon: Image.asset(
            'assets/images/google-g.png',
            width: 20,
            height: 20,
          ),
          label: Text(busy ? 'Đang liên kết…' : 'Liên kết với Google'),
        ),
      ],
    ),
  );
}
