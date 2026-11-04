import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/attachment_picker.dart';
import 'package:organic_mobile/features/feedback/presentation/widgets/feedback_composer.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
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
