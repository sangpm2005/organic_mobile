import 'dart:convert';

/// Debug hints only. These unverified claims must never authorize a session.
/// Return booleans only: no tokens, nonce values, emails or account identifiers.
Map<String, bool> googleTokenDiagnostics(
  String credential, {
  required String clientId,
  required String nonce,
  DateTime? now,
}) {
  try {
    final parts = credential.split('.');
    if (parts.length != 3) return {'readable': false};
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return {'readable': false};
    final audience = payload['aud'];
    final presenter = payload['azp'];
    final expires = payload['exp'];
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return {
      'readable': true,
      'audienceMatches':
          audience == clientId ||
          (audience is List && audience.contains(clientId)),
      'presenterMatchesWebClient': presenter == null || presenter == clientId,
      'nonceMatches': payload['nonce'] == nonce,
      'notExpired': expires is num && expires > seconds,
    };
  } on FormatException {
    return {'readable': false};
  }
}
