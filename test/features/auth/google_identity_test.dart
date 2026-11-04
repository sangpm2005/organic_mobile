import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:organic_mobile/features/auth/data/google_identity.dart';

class CancelledGooglePlatform extends GoogleSignInPlatform {
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
    throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }
}

void main() {
  test(
    'each native attempt initializes exactly once with a fresh server nonce',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final instances = <CancelledGooglePlatform>[];
      final identity = NativeGoogleIdentity(
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
}
