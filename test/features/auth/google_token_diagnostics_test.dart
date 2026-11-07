import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/features/auth/data/google_token_diagnostics.dart';

void main() {
  const client = 'web.apps.googleusercontent.com';
  final now = DateTime.utc(2026, 11, 6);
  final claims = <String, dynamic>{
    'aud': client,
    'azp': 'android.apps.googleusercontent.com',
    'nonce': 'private-nonce',
    'exp': now.millisecondsSinceEpoch ~/ 1000 + 300,
    'email': 'private@example.com',
    'sub': 'private-account',
  };
  String token(Map<String, dynamic> values) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode(values)))}.signature';
  Map<String, bool> inspect(String credential) => googleTokenDiagnostics(
    credential,
    clientId: client,
    nonce: 'private-nonce',
    now: now,
  );

  test('debug checks distinguish audience from Android presenter without disclosing claims', () {
    final credential = token(claims);
    final result = inspect(credential);
    expect(result, {
      'readable': true,
      'audienceMatches': true,
      'presenterMatchesWebClient': false,
      'nonceMatches': true,
      'notExpired': true,
    });
    for (final private in [
      credential,
      client,
      claims['nonce'],
      claims['email'],
      claims['sub'],
    ]) {
      expect(result.toString(), isNot(contains(private)));
    }
  });

  test(
    'detects mismatched audience, nonce and expiry; supports audience arrays',
    () {
      expect(
        inspect(
          token({
            ...claims,
            'aud': [client],
            'azp': client,
          }),
        )['audienceMatches'],
        isTrue,
      );
      expect(
        inspect(token({...claims, 'aud': 'different'}))['audienceMatches'],
        isFalse,
      );
      expect(
        inspect(token({...claims, 'nonce': 'different'}))['nonceMatches'],
        isFalse,
      );
      expect(
        inspect(
          token({...claims, 'exp': now.millisecondsSinceEpoch ~/ 1000}),
        )['notExpired'],
        isFalse,
      );
    },
  );

  test('malformed tokens never leak content or mask the backend error', () {
    for (final value in ['private-token', 'a.%%%.c', 'a.W10.c']) {
      expect(inspect(value), {'readable': false});
    }
  });
}
