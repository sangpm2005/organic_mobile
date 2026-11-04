import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

void main() {
  testWidgets(
    '390px rewards wallet displays scope and prevents use of reserved vouchers',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient(
            (r) async => http.Response(
              jsonEncode({
                'data': r.url.path.endsWith('/reward-transactions')
                    ? []
                    : {
                        'items': [
                          {
                            'id': 'voucher',
                            'voucherCode': 'VC-RESERVED',
                            'name':
                                'Ưu đãi rau xanh dành cho thành viên của Mộc',
                            'discountType': 'percentage',
                            'discountValue': 10,
                            'minOrderValue': 100000,
                            'productNames': ['Rau hữu cơ'],
                            'status': 'reserved',
                            'usable': false,
                            'expiresAt': '2027-01-01T00:00:00',
                          },
                        ],
                        'totalElements': 1,
                      },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      );
      store.user = {'accountId': 'a'};
      store.api.setSession('access', 'refresh');
      store.rewards = {'available': 50};
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: RewardsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ví voucher'));
      await tester.pumpAndSettle();
      expect(find.text('VC-RESERVED'), findsOneWidget);
      expect(find.text('Sản phẩm: Rau hữu cơ'), findsOneWidget);
      expect(find.text('Dùng cho giỏ hàng'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
