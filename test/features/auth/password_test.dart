import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/auth/data/password_repository.dart';
import 'package:organic_mobile/features/auth/presentation/password_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('password validation handles UTF-8, blank text and confirmation', () {
    expect(passwordError('Organic@2026', 'Organic@2026'), isNull);
    expect(passwordError('        ', '        '), isNotNull);
    expect(passwordError('short', 'short'), isNotNull);
    expect(passwordError('ấ' * 25, 'ấ' * 25), isNotNull);
    expect(passwordError('Organic@2026', 'different'), isNotNull);
  });
  test(
    'forgot password never sends the logged-in Authorization header',
    () async {
      final paths = <String>[];
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((r) async {
          paths.add(r.url.path);
          expect(r.headers['Authorization'], isNull);
          if (r.url.path.endsWith('/request')) {
            expect(jsonDecode(r.body), {'email': 'customer@example.com'});
            return response({
              'challengeId': 'challenge',
              'expiresIn': 300,
              'resendAfter': 60,
            });
          }
          if (r.url.path.endsWith('/verify')) {
            expect(jsonDecode(r.body), {
              'challengeId': 'challenge',
              'otp': '123456',
            });
            return response({'resetToken': 'proof', 'expiresIn': 300});
          }
          expect(jsonDecode(r.body), {
            'resetToken': 'proof',
            'newPassword': 'Organic@2027',
            'confirmPassword': 'Organic@2027',
          });
          return response(null);
        }),
      );
      api.setSession('private', 'refresh');
      final repository = PasswordRepository(api, PasswordPurpose.forgot);
      await repository.request(' customer@example.com ');
      await repository.verify('challenge', '123456');
      await repository.complete('proof', 'Organic@2027', 'Organic@2027');
      expect(
        paths.every((p) => p.startsWith('/api/v1/auth/password/forgot/')),
        isTrue,
      );
      api.close();
    },
  );
  testWidgets(
    'change password uses OTP and clears the session only after server success',
    (tester) async {
      final posts = <String>[];
      final store = customer(
        MockClient((r) async {
          posts.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer access');
          if (r.url.path.endsWith('/request')) {
            return response({
              'challengeId': 'change',
              'expiresIn': 300,
              'resendAfter': 60,
              'emailHint': 'c***@example.com',
            });
          }
          if (r.url.path.endsWith('/verify')) {
            return response({'resetToken': 'proof', 'expiresIn': 300});
          }
          return response(null);
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            home: PasswordScreen(purpose: PasswordPurpose.change),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('password.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('c***@example.com'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('password.otp')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('password.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const ValueKey('password.new')),
        'Organic@2027',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password.confirm')),
        'Organic@2027',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('password.submit')));
      await tester.tap(find.byKey(const ValueKey('password.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(posts.length, 3);
      expect(store.loggedIn, isFalse);
      expect(await store.storage.read(key: 'moc.session.v1'), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets('a rejected completion preserves the current account', (
    tester,
  ) async {
    final store = customer(
      MockClient((r) async {
        if (r.url.path.endsWith('/request')) {
          return response({
            'challengeId': 'change',
            'expiresIn': 300,
            'resendAfter': 60,
          });
        }
        if (r.url.path.endsWith('/verify')) {
          return response({'resetToken': 'proof', 'expiresIn': 300});
        }
        return response({'message': 'expired'}, 400);
      }),
    );
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(
          home: PasswordScreen(purpose: PasswordPurpose.change),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('password.submit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('password.otp')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('password.submit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('password.new')),
      'Organic@2027',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password.confirm')),
      'Organic@2027',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('password.submit')));
    await tester.tap(find.byKey(const ValueKey('password.submit')));
    await tester.pumpAndSettle();
    expect(store.loggedIn, isTrue);
    expect(postsPasswordError(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}

bool postsPasswordError(WidgetTester tester) =>
    find.textContaining('Không thể xử lý').evaluate().isNotEmpty;
