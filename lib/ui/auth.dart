import 'package:flutter/material.dart';

import 'widgets.dart';
import 'theme.dart';

Future<bool> ensureLogin(BuildContext context) async {
  if (StoreScope.of(context).loggedIn) {
    return true;
  }
  return await open<bool>(context, const LoginScreen()) == true;
}

class LoginGate extends StatelessWidget {
  final String message;
  const LoginGate(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: EmptyState(
      'Chào bạn đến với Mộc',
      message,
      icon: Icons.person_outline,
      action: FilledButton(
        onPressed: () => open(context, const LoginScreen()),
        child: const Text('Đăng nhập / Đăng ký'),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(), password = TextEditingController();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await StoreScope.of(context).login(username.text, password.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Brand()),
                const SizedBox(height: 40),
                Text(
                  'Chào bạn trở lại.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Đăng nhập để tiếp tục hành trình sống lành cùng Mộc.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('auth.username'),
                  autocorrect: false,
                  controller: username,
                  enabled: !busy,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập tên đăng nhập.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('auth.password'),
                  controller: password,
                  enabled: !busy,
                  obscureText: hidden,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nhập mật khẩu.' : null,
                  onFieldSubmitted: (_) {
                    if (!busy) {
                      submit();
                    }
                  },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Đang đăng nhập…' : 'Đăng nhập'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final registered = await open<bool>(
                            context,
                            const RegisterScreen(),
                          );
                          if (registered == true && context.mounted) {
                            toast(
                              context,
                              'Đã xác thực email. Bạn có thể đăng nhập.',
                            );
                          }
                        },
                  child: const Text('Chưa có tài khoản? Đăng ký cùng Mộc'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => open(
                          context,
                          const RegisterScreen(verifyExisting: true),
                        ),
                  child: const Text('Đã đăng ký? Xác thực email'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  final bool verifyExisting;
  const RegisterScreen({super.key, this.verifyExisting = false});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in [
      'username',
      'fullName',
      'phoneNumber',
      'email',
      'password',
      'confirmPassword',
      'otp',
    ])
      k: TextEditingController(),
  };
  bool otp = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    otp = widget.verifyExisting;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit({bool resend = false}) async {
    if (resend &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
            .hasMatch(fields['email']!.text.trim())) {
      setState(() => error = 'Nhập email đã đăng ký để nhận lại mã OTP.');
      return;
    }
    if (!resend && !form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = StoreScope.of(context).api;
      if (resend) {
        await api.request(
          'POST',
          '/auth/resend-otp',
          authenticated: false,
          body: {'email': fields['email']!.text.trim()},
        );
        if (mounted) {
          toast(context, 'Đã yêu cầu gửi lại mã. Vui lòng kiểm tra email.');
        }
      } else if (otp) {
        await api.request(
          'POST',
          '/auth/verify-otp',
          authenticated: false,
          body: {
            'email': fields['email']!.text.trim(),
            'otp': fields['otp']!.text.trim(),
          },
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        await api.request(
          'POST',
          '/auth/register',
          authenticated: false,
          body: {
            for (final e in fields.entries)
              if (e.key != 'otp')
                e.key: e.key.toLowerCase().contains('password')
                    ? e.value.text
                    : e.value.text.trim(),
          },
        );
        if (mounted) {
          setState(() => otp = true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thành viên của Mộc')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          otp ? 'Xác thực email' : 'Bắt đầu sống lành.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          otp
              ? widget.verifyExisting
                    ? 'Nhập email đã đăng ký và mã OTP. Bạn có thể yêu cầu gửi lại mã nếu cần.'
                    : 'Nhập mã được gửi đến ${fields['email']!.text}.'
              : 'Mộc gửi mã xác thực qua email sau khi bạn đăng ký.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            children: [
              for (final entry
                  in (otp
                          ? {
                              if (widget.verifyExisting)
                                'email': 'Email đã đăng ký',
                              'otp': 'Mã OTP',
                            }
                          : {
                              'fullName': 'Họ và tên',
                              'username': 'Tên đăng nhập',
                              'phoneNumber': 'Số điện thoại',
                              'email': 'Email',
                              'password': 'Mật khẩu',
                              'confirmPassword': 'Nhập lại mật khẩu',
                            })
                      .entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    key: ValueKey('register.${entry.key}'),
                    autocorrect: false,
                    controller: fields[entry.key],
                    enabled: !busy,
                    obscureText: entry.key.toLowerCase().contains('password'),
                    keyboardType: entry.key == 'email'
                        ? TextInputType.emailAddress
                        : ['phoneNumber', 'otp'].contains(entry.key)
                        ? TextInputType.phone
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: entry.value),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập ${entry.value.toLowerCase()}.';
                      }
                      if (entry.key == 'email' &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                        return 'Email chưa hợp lệ.';
                      }
                      if (entry.key == 'password' && v.length < 8) {
                        return 'Mật khẩu cần ít nhất 8 ký tự.';
                      }
                      if (entry.key == 'confirmPassword' &&
                          v != fields['password']!.text) {
                        return 'Hai mật khẩu chưa khớp.';
                      }
                      return null;
                    },
                  ),
                ),
            ],
          ),
        ),
        if (otp)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Mã có hiệu lực 5 phút. Nếu chưa thấy thư, hãy kiểm tra Spam hoặc yêu cầu gửi lại mã.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Đang xử lý…'
                : otp
                ? 'Xác thực tài khoản'
                : 'Tạo tài khoản',
          ),
        ),
        if (otp)
          TextButton(
            onPressed: busy ? null : () => submit(resend: true),
            child: const Text('Gửi lại mã OTP'),
          ),
      ],
    ),
  );
}
