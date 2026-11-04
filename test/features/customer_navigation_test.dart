import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/features/account/presentation/account_screen.dart';
import 'package:organic_mobile/features/notifications/presentation/updates_screen.dart';
import 'package:organic_mobile/features/returns/presentation/return_detail_screen.dart';

import '../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'account exposes customer support, returns, reviews and favorites at 390px',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = customer(
        MockClient((r) async => response({'items': [], 'totalElements': 0})),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: AccountScreen())),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Sản phẩm yêu thích',
        'Đánh giá của tôi',
        'Phản hồi & hỗ trợ',
        'Đổi trả & hoàn tiền',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'inbox opens the native return detail and ignores arbitrary server target URLs',
    (tester) async {
      final paths = <String>[];
      final store = customer(
        MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/return-requests/r')) {
            return response({
              'request': {
                'id': 'r',
                'requestCode': 'RR-01',
                'status': 'pending',
                'requestType': 'refund',
                'reason': 'damaged',
                'order': {'id': 'o', 'orderCode': 'O-1'},
              },
              'actions': {},
              'items': [],
              'description': 'Cần hỗ trợ.',
            });
          }
          return response({'items': [], 'totalElements': 0});
        }),
      );
      store.inbox = [
        {
          'id': 'n',
          'title': 'Cập nhật yêu cầu của bạn',
          'message': 'Cửa hàng đã phản hồi.',
          'returnRequestId': 'r',
          'target': '/admin/return-requests?requestId=r',
          'createdAt': '2026-11-05T00:00:00',
        },
      ];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: UpdatesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật yêu cầu của bạn'));
      await tester.pumpAndSettle();
      expect(find.byType(ReturnDetailScreen), findsOneWidget);
      expect(paths, contains('/api/v1/inbox/n/read'));
      expect(paths, contains('/api/v1/return-requests/r'));
      expect(
        paths.where((p) => p.contains('/management') || p.contains('/admin')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
