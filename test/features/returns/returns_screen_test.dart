import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/widgets/attachment_picker.dart';
import 'package:organic_mobile/features/returns/presentation/return_create_screen.dart';
import 'package:organic_mobile/features/returns/presentation/return_detail_screen.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'backend eligibility denial prevents customer creation controls',
    (tester) async {
      var creates = 0;
      final store = customer(
        MockClient((r) async {
          if (r.method == 'POST') creates++;
          return response({
            'order': {'orderCode': 'O-1'},
            'canSubmit': false,
            'unavailableReason': 'Đơn chưa giao đến khách.',
            'items': [],
          });
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: ReturnCreateScreen('o')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đơn chưa giao đến khách.'), findsOneWidget);
      expect(find.text('Gửi yêu cầu xét duyệt'), findsNothing);
      expect(find.byType(AttachmentPicker), findsNothing);
      expect(creates, 0);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'customer accepts displayed proposal version, refreshes conflict, never approves newer proposal automatically',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var version = 2, submits = 0;
      final store = customer(
        MockClient((r) async {
          if (r.url.path.endsWith('/accept')) {
            submits++;
            expect(jsonDecode(r.body)['proposalVersion'], 2);
            version = 3;
            return response({}, 409);
          }
          if (r.url.path.endsWith('/histories')) {
            return response({'items': [], 'totalElements': 0});
          }
          if (r.url.path.endsWith('/read-thread')) return response(null);
          return response({
            'request': {
              'id': 'r',
              'requestCode': 'RR-001',
              'order': {'id': 'o', 'orderCode': 'O-001'},
              'status': 'approved',
              'proposalVersion': version,
              'requestType': 'return_refund',
              'reason': 'damaged',
              'approvedRefundAmount': 100000,
            },
            'description': 'Sản phẩm bị hư khi giao.',
            'actions': {
              'canAccept': true,
              'canDecline': true,
              'canCancel': false,
            },
            'items': [],
            'evidence': [],
          });
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: ReturnDetailScreen('r')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hủy yêu cầu'), findsNothing);
      await tester.ensureVisible(find.text('Đồng ý phương án'));
      await tester.tap(find.text('Đồng ý phương án'));
      await tester.pumpAndSettle();
      expect(find.text('Đồng ý phương án lần 2'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(submits, 1);
      expect(version, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      store.dispose();
    },
  );
}
