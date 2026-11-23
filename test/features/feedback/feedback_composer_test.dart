import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/attachment_picker.dart';
import 'package:organic_mobile/features/feedback/presentation/widgets/feedback_composer.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'subject suggestions follow the support type without overwriting custom text',
    (tester) async {
      final completed = Completer<void>();
      Map<String, dynamic>? submitted;
      var created = 0;
      final store = customer(
        MockClient((request) async {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          await completed.future;
          return response({
            'feedback': {'id': 'feedback'},
          });
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: organicTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedbackComposer(
                  canUpload: false,
                  onSaved: () {},
                  onUncertain: () {},
                  onCreated: (_) => created++,
                ),
              ),
            ),
          ),
        ),
      );
      final subjectField = find.byKey(const ValueKey('feedback.subject'));
      final typeField = find.byKey(const ValueKey('feedback.type'));
      String subjectText() =>
          tester.widget<TextFormField>(subjectField).controller!.text;
      Future<void> chooseType(String label) async {
        await tester.ensureVisible(typeField);
        await tester.tap(typeField);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await tester.tap(
        find.widgetWithText(ActionChip, 'Cách bảo quản sản phẩm'),
      );
      await tester.pump();
      expect(subjectText(), 'Cách bảo quản sản phẩm');
      await tester.enterText(subjectField, 'Hỏi về sản phẩm trong đơn của tôi');
      tester.testTextInput.hide();
      await chooseType('Giao hàng');
      expect(subjectText(), 'Hỏi về sản phẩm trong đơn của tôi');
      expect(find.widgetWithText(ActionChip, 'Giao hàng chậm'), findsOneWidget);
      await chooseType('Dịch vụ');
      expect(
        find.widgetWithText(ActionChip, 'Cần nhân viên tư vấn'),
        findsOneWidget,
      );
      await chooseType('Góp ý khác');
      expect(
        find.widgetWithText(ActionChip, 'Đề xuất sản phẩm mới'),
        findsOneWidget,
      );
      await chooseType('Thanh toán');
      expect(subjectText(), 'Hỏi về sản phẩm trong đơn của tôi');
      expect(find.widgetWithText(ActionChip, 'Giao hàng chậm'), findsNothing);
      await tester.tap(
        find.widgetWithText(ActionChip, 'Thanh toán chưa cập nhật'),
      );
      await tester.pump();
      expect(subjectText(), 'Thanh toán chưa cập nhật');
      await tester.enterText(subjectField, 'Thanh toán đơn hàng chưa cập nhật');
      await tester.enterText(
        find.byKey(const ValueKey('feedback.content')),
        'Tôi đã thanh toán, nhờ cửa hàng kiểm tra giúp.',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Gửi phản hồi'));
      await tester.tap(find.text('Gửi phản hồi'));
      await tester.pump();
      expect(submitted?['feedbackType'], 'payment');
      expect(submitted?['subject'], 'Thanh toán đơn hàng chưa cập nhật');
      expect(
        submitted?['content'],
        'Tôi đã thanh toán, nhờ cửa hàng kiểm tra giúp.',
      );
      expect(tester.widget<TextFormField>(subjectField).enabled, isFalse);
      for (final chip in tester.widgetList<ActionChip>(
        find.byType(ActionChip),
      )) {
        expect(chip.onPressed, isNull);
      }
      completed.complete();
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('subject suggestions fit ${width}px with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = customer(MockClient((_) async => response({})));
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: organicTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FeedbackComposer(
                  canUpload: false,
                  onSaved: () {},
                  onUncertain: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('feedback.type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thanh toán').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ActionChip, 'Thanh toán không thành công'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets(
    'retry of known failed attachment never resends text or a confirmed image',
    (tester) async {
      var creates = 0, first = 0, second = 0, done = 0;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/feedbacks')) {
            creates++;
            return response({
              'feedback': {'id': 'feedback'},
            });
          }
          final body = utf8.decode(r.bodyBytes, allowMalformed: true);
          if (body.contains('filename="first.png"')) {
            first++;
            return response({'id': 'first'});
          }
          second++;
          return response({'id': 'second'}, second == 1 ? 400 : 200);
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedbackComposer(
                  onSaved: () {},
                  onUncertain: () {},
                  onCreated: (_) => done++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Hàng bị dập');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Cần cửa hàng hỗ trợ đơn hàng.',
      );
      tester.widget<AttachmentPicker>(find.byType(AttachmentPicker)).onChanged([
        image('first.png'),
        image('second.png'),
      ]);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Gửi phản hồi'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Gửi phản hồi'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(first, 1);
      expect(second, 1);
      expect(done, 0);
      await tester.ensureVisible(find.text('Tải lại tệp còn thiếu'));
      await tester.tap(find.text('Tải lại tệp còn thiếu'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(first, 1);
      expect(second, 2);
      expect(done, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'uncertain reply is locked until explicit review and never silently retries',
    (tester) async {
      var writes = 0, checks = 0;
      final store = customer(
        MockClient((r) async {
          writes++;
          return response({}, 503);
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedbackComposer(
                  feedbackId: 'f',
                  onSaved: () {},
                  onUncertain: () => checks++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Xin hỗ trợ đơn hàng.',
      );
      expect(find.byType(ActionChip), findsNothing);
      tester.testTextInput.hide();
      await tester.tap(find.text('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Kiểm tra nội dung đã gửi'));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(writes, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
