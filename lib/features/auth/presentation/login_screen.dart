import 'package:flutter/material.dart';
import 'package:organic_mobile/features/auth/presentation/register_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/brand.dart';

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
