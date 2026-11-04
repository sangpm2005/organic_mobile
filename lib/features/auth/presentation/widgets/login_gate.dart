import 'package:flutter/material.dart';
import 'package:organic_mobile/features/auth/presentation/login_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';

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
      'Chào bạn đến với organicfood',
      message,
      icon: Icons.person_outline,
      action: FilledButton(
        onPressed: () => open(context, const LoginScreen()),
        child: const Text('Đăng nhập / Đăng ký'),
      ),
    ),
  );
}
