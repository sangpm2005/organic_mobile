import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/state/organic_store.dart';
import '../../../core/utils/json.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/panel.dart';
import '../data/password_repository.dart';

/// OTP and the short-lived password grant stay in memory, never in a route/storage.
class PasswordScreen extends StatefulWidget {
  final PasswordPurpose purpose;
  const PasswordScreen({super.key, this.purpose = PasswordPurpose.forgot});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), otp = TextEditingController();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  OrganicStore? store;
  int? session;
  Json? challenge;
  String? token, error;
  DateTime? resendAt, expiresAt, grantExpiresAt;
  Timer? timer;
  bool busy = false, hidden = true;
  bool get changing => widget.purpose == PasswordPurpose.change;
  int get remaining => resendAt == null
      ? 0
      : resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
  bool get current =>
      !changing || (store!.loggedIn && store!.api.sessionVersion == session);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store ??= StoreScope.of(context);
    session ??= store!.api.sessionVersion;
    timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> run(Future<void> Function(PasswordRepository) action) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action(PasswordRepository(store!.api, widget.purpose));
    } catch (e) {
      if (mounted && current) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> request() async {
    if (remaining > 0 ||
        (!changing && challenge == null && !form.currentState!.validate())) {
      return;
    }
    await run((service) async {
      final result = await service.request(email.text);
      if (!mounted || !current) return;
      setState(() {
        challenge = result;
        token = null;
        otp.clear();
        resendAt = DateTime.now().add(
          Duration(seconds: number(result['resendAfter']).toInt()),
        );
        expiresAt = DateTime.now().add(
          Duration(seconds: number(result['expiresIn']).toInt()),
        );
      });
    });
  }

  Future<void> submit() async {
    if (challenge == null) return request();
    if (!form.currentState!.validate()) return;
    await run((service) async {
      if (token == null) {
        if (!expiresAt!.isAfter(DateTime.now())) {
          throw Exception('Mã đã hết hạn. Vui lòng gửi lại mã.');
        }
        final result = await service.verify(
          '${challenge!['challengeId']}',
          otp.text,
        );
        if (!mounted || !current) return;
        if ('${result['resetToken'] ?? ''}'.isEmpty ||
            number(result['expiresIn']) <= 0) {
          throw Exception('Vui lòng xác thực lại mã.');
        }
        setState(() {
          token = '${result['resetToken']}';
          otp.clear();
          grantExpiresAt = DateTime.now().add(
            Duration(seconds: number(result['expiresIn']).toInt()),
          );
        });
      } else {
        if (!grantExpiresAt!.isAfter(DateTime.now())) {
          setState(() {
            token = null;
            challenge = null;
          });
          throw Exception(
            'Thời gian đổi mật khẩu đã hết. Vui lòng gửi mã mới.',
          );
        }
        await service.complete(token!, password.text, confirmation.text);
        if (!mounted || !current) return;
        token = null;
        password.clear();
        confirmation.clear();
        if (changing) await store!.clearLocalSession();
        if (!mounted) return;
        toast(context, 'Đã cập nhật mật khẩu. Vui lòng đăng nhập lại.');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    token = null;
    for (final c in [email, otp, password, confirmation]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(changing ? 'Đổi mật khẩu' : 'Quên mật khẩu')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  token != null
                      ? 'Tạo mật khẩu mới'
                      : challenge != null
                      ? 'Xác thực email'
                      : changing
                      ? 'Bảo vệ tài khoản của bạn'
                      : 'Lấy lại mật khẩu',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (!current)
                  const Text(
                    'Phiên đăng nhập đã thay đổi. Vui lòng mở lại chức năng này.',
                  )
                else ...[
                  if (challenge == null) ...[
                    const Text(
                      'Mã xác thực có hiệu lực 5 phút sẽ được gửi đến email tài khoản.',
                    ),
                    if (!changing) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const ValueKey('password.email'),
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email đăng ký',
                        ),
                        validator: (v) =>
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Nhập email hợp lệ.',
                      ),
                    ],
                  ] else if (token == null) ...[
                    Panel(
                      child: Text(
                        '${challenge!['message'] ?? 'Kiểm tra email để lấy mã xác thực.'}'
                        '${challenge!['emailHint'] == null ? '' : '\n${challenge!['emailHint']}'}',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('password.otp'),
                      controller: otp,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Mã xác thực 6 chữ số',
                      ),
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                          ? null
                          : 'Nhập đủ 6 chữ số.',
                    ),
                    TextButton(
                      onPressed: busy || remaining > 0 ? null : request,
                      child: Text(
                        remaining > 0
                            ? 'Gửi lại mã sau ${remaining}s'
                            : 'Gửi lại mã',
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Dùng ít nhất 8 ký tự và không dùng lại mật khẩu hiện tại.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('password.new'),
                      controller: password,
                      enabled: !busy,
                      obscureText: hidden,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
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
                      validator: (v) => passwordError(v ?? '', v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('password.confirm'),
                      controller: confirmation,
                      enabled: !busy,
                      obscureText: hidden,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu mới',
                      ),
                      validator: (v) => v == password.text
                          ? null
                          : 'Mật khẩu xác nhận chưa khớp.',
                    ),
                  ],
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
                    key: const ValueKey('password.submit'),
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Đang xử lý…'
                          : token != null
                          ? 'Lưu mật khẩu mới'
                          : challenge != null
                          ? 'Xác thực mã'
                          : 'Gửi mã xác thực',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
