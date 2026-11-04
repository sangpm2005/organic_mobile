import 'package:flutter/foundation.dart';
import 'package:google_sign_in_android/google_sign_in_android.dart';
import 'package:google_sign_in_ios/google_sign_in_ios.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

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
  NativeGoogleIdentity({this.platformFactory});
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

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
    if (defaultTargetPlatform == TargetPlatform.iOS && _iosClientId.isEmpty) {
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
          clientId: _iosClientId.isEmpty ? null : _iosClientId,
          serverClientId: clientId,
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
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiException(
        'Chưa đăng nhập được bằng Google. Vui lòng thử lại hoặc dùng mật khẩu.',
      );
    }
  }
}
