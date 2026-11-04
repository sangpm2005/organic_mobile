import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/shared/widgets/async_view.dart';

void main() {
  testWidgets('retry shows loading and renders a successful response', (
    tester,
  ) async {
    final first = Completer<String>();
    final retry = Completer<String>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncView<String>(
            load: () => ++calls == 1 ? first.future : retry.future,
            builder: (value) => Text(value),
          ),
        ),
      ),
    );
    first.completeError(Exception('Offline'));
    await tester.pump();
    expect(find.text('Chưa tải được dữ liệu'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);

    retry.complete('Đã tải sản phẩm');
    await tester.pump();
    expect(find.text('Đã tải sản phẩm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed retry stays recoverable without unhandled errors', (
    tester,
  ) async {
    final attempts = List.generate(3, (_) => Completer<String>());
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncView<String>(
            load: () => attempts[calls++].future,
            builder: (value) => Text(value),
          ),
        ),
      ),
    );
    attempts[0].completeError(Exception('Offline'));
    await tester.pump();
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    attempts[1].completeError(Exception('Still offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Exception: Still offline'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    attempts[2].complete('Connected');
    await tester.pump();
    expect(calls, 3);
    expect(find.text('Connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
