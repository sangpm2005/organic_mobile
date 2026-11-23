import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/auth/presentation/login_screen.dart';
import 'package:organic_mobile/features/auth/presentation/register_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'login preserves composed username and submits literal credentials',
    (tester) async {
      Map<String, dynamic>? submitted;
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((request) async {
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            return response({}, 400);
          }),
        ),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      final username = find.byKey(const ValueKey('auth.username'));
      final password = find.byKey(const ValueKey('auth.password'));
      await tester.tap(username);
      for (final text in ['c', 'cu', 'cus', 'customer']) {
        final value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: 0, end: text.length),
        );
        tester.testTextInput.updateEditingValue(value);
        await tester.pump();
        expect(tester.widget<TextFormField>(username).controller!.value, value);
      }
      final usernameInput = tester.widget<TextField>(
        find.descendant(of: username, matching: find.byType(TextField)),
      );
      expect(usernameInput.keyboardType, TextInputType.visiblePassword);
      expect(usernameInput.autocorrect, isFalse);
      expect(usernameInput.enableSuggestions, isFalse);
      await tester.enterText(password, 'Customer@2026');
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      final passwordInput = tester.widget<TextField>(
        find.descendant(of: password, matching: find.byType(TextField)),
      );
      expect(passwordInput.obscureText, isFalse);
      expect(passwordInput.autocorrect, isFalse);
      expect(passwordInput.enableSuggestions, isFalse);
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Đăng nhập'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(submitted?['username'], 'customer');
      expect(submitted?['password'], 'Customer@2026');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'registration keeps Vietnamese name composition and literal identifiers',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((_) async => response({}, 400)),
        ),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      final fullName = find.byKey(const ValueKey('register.fullName'));
      await tester.tap(fullName);
      const composingName = TextEditingValue(
        text: 'Nguyễn Trọng Vĩ',
        selection: TextSelection.collapsed(offset: 14),
        composing: TextRange(start: 12, end: 14),
      );
      tester.testTextInput.updateEditingValue(composingName);
      await tester.pump();
      expect(
        tester.widget<TextFormField>(fullName).controller!.value,
        composingName,
      );
      for (final key in ['username', 'email', 'password', 'confirmPassword']) {
        final field = find.byKey(ValueKey('register.$key'));
        await tester.ensureVisible(field);
        final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        );
        expect(input.autocorrect, isFalse);
        expect(input.enableSuggestions, isFalse);
        expect(input.inputFormatters ?? [], isEmpty);
        expect(input.smartDashesType, SmartDashesType.disabled);
        expect(input.smartQuotesType, SmartQuotesType.disabled);
      }
      final username = find.byKey(const ValueKey('register.username'));
      await tester.ensureVisible(username);
      await tester.enterText(username, 'customer');
      expect(
        tester.widget<TextFormField>(username).controller!.text,
        'customer',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
