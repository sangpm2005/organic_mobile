/// Public OAuth identifiers. Never put a Google Client Secret in this file.
abstract final class GoogleAuthConfig {
  /// Must match the backend's Web OAuth Client ID, not the Android Client ID.
  /// Override for another environment with --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '231372985900-indb0dpaaq2c4177dql94ksr8h2ll5cl.apps.googleusercontent.com',
  );

  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
}
