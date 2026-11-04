import 'package:organic_mobile/shared/widgets/session_boundary.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/app/organic_app.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

void main() {
  testWidgets(
    'private route survives token refresh but hides data after account change',
    (tester) async {
      final store = OrganicStore(
        api: OrganicApi(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      store.user = {'accountId': 'a'};
      store.api.setSession('account-a', 'refresh-a');
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            home: SessionBoundary(child: Scaffold(body: Text('PRIVATE A'))),
          ),
        ),
      );
      expect(find.text('PRIVATE A'), findsOneWidget);
      store.api.accessToken = 'refreshed-a';
      store.notifyListeners();
      await tester.pump();
      expect(find.text('PRIVATE A'), findsOneWidget);
      store.user = {'accountId': 'b'};
      store.api.setSession('account-b', 'refresh-b');
      store.notifyListeners();
      await tester.pump();
      expect(find.text('PRIVATE A'), findsNothing);
      expect(find.text('Phiên đăng nhập đã thay đổi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    '390px storefront navigates to customer sign in without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((request) async {
            final data = request.url.path.endsWith('/home')
                ? {'content': {}, 'categories': [], 'featuredProducts': []}
                : {'items': [], 'totalElements': 0};
            return http.Response(
              jsonEncode({'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(OrganicApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Lành từ đất.\nTốt cho bạn.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
      await tester.tap(find.text('Đăng nhập / Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Chào bạn trở lại.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
