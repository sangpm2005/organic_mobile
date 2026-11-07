import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/auth/presentation/login_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import 'google_auth_test.dart'
    show FakeGoogleIdentity, challenge, challengeCookie, envelope, loginData;

Future<void> openLogin(WidgetTester tester, OrganicStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Mở đăng nhập'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở đăng nhập'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('auth.google')));
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Google cancellation unlocks the form without requiring a password or posting login',
    (tester) async {
      final selection = Completer<String?>();
      var nativeCalls = 0, loginPosts = 0;
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/challenge')) {
              return challenge(cookie: challengeCookie);
            }
            loginPosts++;
            return envelope(loginData);
          }),
        ),
        googleIdentity: FakeGoogleIdentity((_, _) {
          nativeCalls++;
          return selection.future;
        }),
      );
      await openLogin(tester, store);
      await tester.tap(find.byKey(const ValueKey('auth.google')));
      await tester.pump();
      expect(find.text('Nhập tên đăng nhập.'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('auth.google')))
            .onPressed,
        isNull,
      );
      selection.complete(null);
      await tester.pumpAndSettle();
      expect(nativeCalls, 1);
      expect(loginPosts, 0);
      expect(
        find.textContaining('Đăng nhập Google chưa hoàn tất.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('auth.google')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'a Google provider failure is visible without requiring the password form',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient(
            (request) async => challenge(cookie: challengeCookie),
          ),
        ),
        googleIdentity: FakeGoogleIdentity((_, _) async {
          throw const ApiException(
            'Đăng nhập Google chưa được cấu hình cho bản ứng dụng này.',
          );
        }),
      );
      await openLogin(tester, store);
      await tester.tap(find.byKey(const ValueKey('auth.google')));
      await tester.pumpAndSettle();
      expect(store.loggedIn, false);
      expect(
        find.textContaining('Đăng nhập Google chưa được cấu hình'),
        findsOneWidget,
      );
      expect(find.text('Nhập mật khẩu.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'a new Google customer can complete their phone number before leaving login',
    (tester) async {
      String? phone;
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/challenge')) {
              return challenge(cookie: challengeCookie);
            }
            if (request.url.path.endsWith('/auth/google')) {
              return envelope(loginData);
            }
            if (request.url.path.endsWith('/customers/me')) {
              if (request.method == 'PUT') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['fullName'], 'Khách Google');
                phone = body['phoneNumber'] as String;
              }
              return envelope({
                'fullName': 'Khách Google',
                'email': 'customer@example.test',
                'phoneNumber': phone,
              });
            }
            return envelope({'items': [], 'totalElements': 0});
          }),
        ),
        googleIdentity: FakeGoogleIdentity((_, _) async => 'google-id-token'),
      );
      await openLogin(tester, store);
      await tester.tap(find.byKey(const ValueKey('auth.google')));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(store.profileCompletionRequired, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('profile.phoneNumber')),
        '0900000000',
      );
      await tester.ensureVisible(find.text('Lưu thông tin'));
      await tester.tap(find.text('Lưu thông tin'));
      await tester.pumpAndSettle();
      expect(phone, '0900000000');
      expect(store.profileCompletionRequired, isFalse);
      expect(find.text('Mở đăng nhập'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
