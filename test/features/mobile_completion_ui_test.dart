import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/features/auth/presentation/password_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../helpers/customer_fixtures.dart';

void main() {
  testWidgets('password steps fit a 390px phone', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final family in ['BeVietnamPro', 'Lora']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'Lora'
                ? 'assets/fonts/Lora.ttf'
                : 'assets/fonts/BeVietnamPro-Regular.ttf',
          ),
        );
      await loader.load();
    }
    final store = customer(
      MockClient(
        (r) async => r.url.path.endsWith('/verify')
            ? response({'resetToken': 'proof', 'expiresIn': 300})
            : response({
                'challengeId': 'challenge',
                'expiresIn': 300,
                'resendAfter': 60,
                'message': 'Nếu email có tài khoản hợp lệ, hệ thống đã gửi mã xác thực.',
              }),
      ),
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: organicTheme(),
          home: RepaintBoundary(key: boundary, child: const PasswordScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('.local/mobile-qa/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('password-email');
    await tester.enterText(
      find.byKey(const ValueKey('password.email')),
      'customer@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('password.submit')));
    await tester.pumpAndSettle();
    await capture('password-otp');
    await tester.enterText(
      find.byKey(const ValueKey('password.otp')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('password.submit')));
    await tester.pumpAndSettle();
    await capture('password-new');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
