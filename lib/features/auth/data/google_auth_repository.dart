import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';
import 'google_identity.dart';
import 'google_token_diagnostics.dart';

class GoogleAuthRepository {
  final OrganicApi api;
  final GoogleIdentity identity;
  bool _busy = false;
  GoogleAuthRepository(this.api, {GoogleIdentity? identity})
    : identity = identity ?? NativeGoogleIdentity();

  bool get supported => identity.supported;

  Future<Json?> login({required bool Function() isCurrent}) =>
      _authenticate(link: false, isCurrent: isCurrent);

  Future<Json?> link({
    required String currentPassword,
    required bool Function() isCurrent,
  }) => _authenticate(
    link: true,
    currentPassword: currentPassword,
    isCurrent: isCurrent,
  );

  Future<Json?> _authenticate({
    required bool link,
    required bool Function() isCurrent,
    String? currentPassword,
  }) async {
    if (!supported) {
      throw const ApiException('Đăng nhập Google chưa hỗ trợ thiết bị này.');
    }
    if (_busy) {
      throw const ApiException('Đang xử lý đăng nhập Google. Vui lòng chờ.');
    }
    _busy = true;
    String? cookie;
    final session = api.sessionVersion;
    bool active() => isCurrent() && (!link || session == api.sessionVersion);
    try {
      if (!active()) return null;
      final challenge = object(
        await api.request(
          'POST',
          link ? '/auth/google/link/challenge' : '/auth/google/challenge',
          authenticated: link,
          followRedirects: false,
          onResponseHeaders: (headers) {
            final value = headers['set-cookie'] ?? '';
            final match = RegExp(
              r'(?:^|,\s*)organic_google_auth=([A-Za-z0-9_-]{43})(?:;|$)',
            ).firstMatch(value);
            if (RegExp(
                  r';\s*secure(?:;|$)',
                  caseSensitive: false,
                ).hasMatch(value) &&
                Uri.parse(api.baseUrl).scheme != 'https') {
              throw const ApiException(
                'Đăng nhập Google cần kết nối an toàn tới máy chủ.',
              );
            }
            cookie = match?.group(1);
          },
        ),
      );
      if (!active()) return null;
      final clientId = challenge['clientId'], nonce = challenge['nonce'];
      if (clientId is! String ||
          !clientId.endsWith('.apps.googleusercontent.com') ||
          nonce is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(nonce) ||
          cookie == null) {
        throw const ApiException(
          'Chưa bắt đầu được đăng nhập Google. Vui lòng thử lại.',
        );
      }
      final credential = await identity.authenticate(
        clientId: clientId,
        nonce: nonce,
      );
      if (credential == null || !active()) return null;
      if (link) {
        // Refresh the app's JWT after the Google dialog, if needed. The link
        // endpoint also uses 401 for an incorrect current password, which must
        // not clear an otherwise valid app session.
        await api.request('GET', '/customers/me');
        if (!active() || api.accessToken == null) return null;
      }
      try {
        return object(
          await api.request(
            'POST',
            link ? '/auth/google/link' : '/auth/google',
            authenticated: false,
            retry: false,
            followRedirects: false,
            headers: {
              'Cookie': 'organic_google_auth=$cookie',
              if (link) 'Authorization': 'Bearer ${api.accessToken}',
            },
            body: {
              'credential': credential,
              if (link)
                'currentPassword': currentPassword!.isEmpty
                    ? null
                    : currentPassword
              else
                'rememberMe': true,
            },
          ),
        );
      } on ApiException catch (error) {
        if (kDebugMode && error.status == 401) {
          debugPrint(
            '[GoogleAuth] Backend rejected credential; unverified checks: '
            '${googleTokenDiagnostics(credential, clientId: clientId, nonce: nonce)}',
          );
        }
        rethrow;
      }
    } finally {
      // The challenge cookie and Google ID token only live for this attempt.
      cookie = null;
      _busy = false;
    }
  }
}
