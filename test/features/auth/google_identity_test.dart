import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:organic_mobile/features/auth/data/google_identity.dart';
import 'package:organic_mobile/core/config/google_auth_config.dart';
import 'package:organic_mobile/core/network/api_exception.dart';

class CancelledGooglePlatform extends GoogleSignInPlatform {
  final GoogleSignInException failure;
  CancelledGooglePlatform({
    this.failure = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    ),
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected platform call: ${invocation.memberName}',
  );
  InitParameters? initialized;
  @override
  Future<void> init(InitParameters params) async {
    expect(initialized, isNull);
    initialized = params;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    throw failure;
  }
}

void main() {
  for (final description in [
    '[16] Account reauth failed.',
    '[8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].',
  ]) {
    test(
      'provider cancellation with $description is not treated as user cancellation',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final identity = NativeGoogleIdentity(
          webClientId: 'server.apps.googleusercontent.com',
          platformFactory: () => CancelledGooglePlatform(
            failure: GoogleSignInException(
              code: GoogleSignInExceptionCode.canceled,
              description: description,
            ),
          ),
        );
        await expectLater(
          identity.authenticate(
            clientId: 'server.apps.googleusercontent.com',
            nonce: 'nonce',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Google'),
            ),
          ),
        );
      },
    );
  }

  test('an explicit user dismissal remains a cancellation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final identity = NativeGoogleIdentity(
      webClientId: 'server.apps.googleusercontent.com',
      platformFactory: () => CancelledGooglePlatform(
        failure: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'activity is cancelled by the user.',
        ),
      ),
    );
    expect(
      await identity.authenticate(
        clientId: 'server.apps.googleusercontent.com',
        nonce: 'nonce',
      ),
      isNull,
    );
  });
  test(
    'each native attempt initializes exactly once with a fresh server nonce',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final instances = <CancelledGooglePlatform>[];
      final identity = NativeGoogleIdentity(
        webClientId: 'server.apps.googleusercontent.com',
        platformFactory: () {
          final platform = CancelledGooglePlatform();
          instances.add(platform);
          return platform;
        },
      );
      expect(
        await identity.authenticate(
          clientId: 'server.apps.googleusercontent.com',
          nonce: 'first',
        ),
        isNull,
      );
      expect(
        await identity.authenticate(
          clientId: 'server.apps.googleusercontent.com',
          nonce: 'second',
        ),
        isNull,
      );
      expect(instances, hasLength(2));
      expect(
        instances[0].initialized!.serverClientId,
        'server.apps.googleusercontent.com',
      );
      expect(instances.map((p) => p.initialized!.nonce), ['first', 'second']);
    },
  );

  test(
    'project Web Client ID is supplied explicitly to the native SDK',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final platform = CancelledGooglePlatform();
      final identity = NativeGoogleIdentity(platformFactory: () => platform);
      await identity.authenticate(
        clientId: GoogleAuthConfig.webClientId,
        nonce: 'fresh-nonce',
      );
      expect(
        platform.initialized!.serverClientId,
        GoogleAuthConfig.webClientId,
      );
      expect(platform.initialized!.clientId, isNull);
    },
  );

  test(
    'a different environment can override the public Web Client ID',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final platform = CancelledGooglePlatform();
      final identity = NativeGoogleIdentity(
        webClientId: 'staging.apps.googleusercontent.com',
        platformFactory: () => platform,
      );
      await identity.authenticate(
        clientId: 'staging.apps.googleusercontent.com',
        nonce: 'staging-nonce',
      );
      expect(
        platform.initialized!.serverClientId,
        'staging.apps.googleusercontent.com',
      );
      expect(platform.initialized!.nonce, 'staging-nonce');
    },
  );

  test('mismatched client IDs stop before opening Google', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final identity = NativeGoogleIdentity(
      webClientId: 'wrong.apps.googleusercontent.com',
      platformFactory: () => throw StateError('Must not open Google'),
    );
    await expectLater(
      identity.authenticate(
        clientId: 'server.apps.googleusercontent.com',
        nonce: 'nonce',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('chưa khớp'),
        ),
      ),
    );
  });
}
