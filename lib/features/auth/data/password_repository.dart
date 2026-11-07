import 'dart:convert';

import '../../../core/network/organic_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

enum PasswordPurpose { forgot, change }

class PasswordRepository {
  final OrganicApi api;
  final PasswordPurpose purpose;
  PasswordRepository(this.api, this.purpose);
  String get _path => '/auth/password/${purpose.name}';
  bool get _authenticated => purpose == PasswordPurpose.change;

  Future<Json> request(String email) async {
    final result = object(
      await api.request(
        'POST',
        '$_path/request',
        authenticated: _authenticated,
        body: _authenticated ? null : {'email': email.trim()},
      ),
    );
    if ('${result['challengeId'] ?? ''}'.isEmpty ||
        number(result['expiresIn']) <= 0) {
      throw const ApiException('Chưa nhận được mã xác thực. Vui lòng thử lại.');
    }
    return result;
  }

  Future<Json> verify(String challengeId, String otp) async => object(
    await api.request(
      'POST',
      '$_path/verify',
      authenticated: _authenticated,
      body: {'challengeId': challengeId, 'otp': otp.trim()},
    ),
  );

  Future<void> complete(
    String token,
    String password,
    String confirmation,
  ) async {
    final error = passwordError(password, confirmation);
    if (error != null) throw ApiException(error);
    await api.request(
      'POST',
      '$_path/complete',
      authenticated: _authenticated,
      body: {
        'resetToken': token,
        'newPassword': password,
        'confirmPassword': confirmation,
      },
    );
  }
}

String? passwordError(String password, String confirmation) {
  if (password.trim().isEmpty || password.length < 8) {
    return 'Mật khẩu phải có ít nhất 8 ký tự.';
  }
  if (utf8.encode(password).length > 72) {
    return 'Mật khẩu quá dài. Hãy giảm độ dài hoặc số ký tự có dấu.';
  }
  if (password != confirmation) return 'Mật khẩu xác nhận chưa khớp.';
  return null;
}
