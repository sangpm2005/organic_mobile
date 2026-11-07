import 'package:flutter/foundation.dart';
import 'package:google_sign_in_android/google_sign_in_android.dart';
import 'package:google_sign_in_ios/google_sign_in_ios.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import '../../../core/config/google_auth_config.dart';
import '../../../core/network/api_exception.dart';

abstract class GoogleIdentity {
  bool get supported;
  Future<String?> authenticate({
    required String clientId,
    required String nonce,
  });
}

class NativeGoogleIdentity implements GoogleIdentity {
  final GoogleSignInPlatform Function()? platformFactory;
  final String webClientId;
  NativeGoogleIdentity({
    this.platformFactory,
    this.webClientId = GoogleAuthConfig.webClientId,
  });

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> authenticate({
    required String clientId,
    required String nonce,
  }) async {
    if (!supported) {
      throw const ApiException('Đăng nhập Google chưa hỗ trợ thiết bị này.');
    }
    final configuredClientId = webClientId.trim();
    if (configuredClientId.isEmpty || configuredClientId != clientId) {
      throw const ApiException(
        'Web Client ID trong mobile chưa khớp với cấu hình Google của máy chủ. Vui lòng kiểm tra cấu hình đăng nhập Google.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        GoogleAuthConfig.iosClientId.isEmpty) {
      throw const ApiException(
        'Đăng nhập Google chưa sẵn sàng. Bạn có thể đăng nhập bằng mật khẩu.',
      );
    }
    // Each attempt needs a fresh server nonce. Initialize a new platform
    // instance once per attempt instead of reinitializing Google's singleton.
    final GoogleSignInPlatform platform =
        platformFactory?.call() ??
        (defaultTargetPlatform == TargetPlatform.android
            ? GoogleSignInAndroid()
            : GoogleSignInIOS());
    try {
      await platform.init(
        InitParameters(
          clientId: GoogleAuthConfig.iosClientId.isEmpty
              ? null
              : GoogleAuthConfig.iosClientId,
          serverClientId: configuredClientId,
          nonce: nonce,
        ),
      );
      final result = await platform.authenticate(
        const AuthenticateParameters(),
      );
      final token = result.authenticationTokens.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException('Google chưa trả về thông tin đăng nhập.');
      }
      return token;
    } on GoogleSignInException catch (error) {
      final description = (error.description ?? '').toLowerCase();
      // Credential Manager also labels some provider/configuration failures as
      // canceled. Preserve explicit errors instead of silently returning null.
      if (description.contains('unregistered_on_api_console') ||
          error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const ApiException(
          'Đăng nhập Google chưa được cấu hình cho bản ứng dụng này. Vui lòng liên hệ cửa hàng hoặc đăng nhập bằng tài khoản organicfood đã có.',
        );
      }
      if (description.contains('reauth failed')) {
        throw const ApiException(
          'Google chưa xác thực được tài khoản nên chưa thể đăng nhập. Hãy thử lại; nếu vẫn gặp lỗi sau khi chọn tài khoản, vui lòng liên hệ cửa hàng.',
        );
      }
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const ApiException(
          'Dịch vụ đăng nhập Google trên thiết bị chưa sẵn sàng. Vui lòng kiểm tra Google Play services và cấu hình đăng nhập của ứng dụng.',
        );
      }
      throw const ApiException(
        'Chưa đăng nhập được bằng Google. Vui lòng thử lại hoặc dùng mật khẩu.',
      );
    }
  }
}
