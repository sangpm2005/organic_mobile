import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:organic_mobile/main.dart' as app;
import 'package:organic_mobile/app/organic_app.dart';
import 'package:organic_mobile/core/utils/json.dart';

const bridge = String.fromEnvironment('UAT_BRIDGE');
const token = String.fromEnvironment('UAT_TOKEN');
final cases = <Json>[];

// Keep form input deterministic while exercising the real Android UI and HTTP.
class AcceptanceBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestTextInput => true;
}

Future<dynamic> control(String path, [Json? data]) async {
  final uri = Uri.parse('$bridge$path');
  final headers = {'X-UAT-Token': token, 'Content-Type': 'application/json'};
  final response = data == null
      ? await http.get(uri, headers: headers)
      : await http.post(uri, headers: headers, body: jsonEncode(data));
  if (response.statusCode != 200) {
    throw StateError(
      'UAT control $path HTTP ${response.statusCode}: ${response.body}',
    );
  }
  return jsonDecode(response.body);
}

Finder key(String value) => find.byKey(ValueKey(value));
Finder vertical() {
  final lists = find.byType(ListView);
  if (lists.evaluate().isNotEmpty) {
    return find
        .descendant(of: lists.last, matching: find.byType(Scrollable))
        .first;
  }
  return find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;
}

Future<void> waitFor(WidgetTester t, Finder finder, {int seconds = 40}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  bool exists() {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  while (!exists() && DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets, reason: 'Timed out waiting for $finder');
}

Future<void> reveal(WidgetTester t, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await waitFor(t, vertical());
    t.state<ScrollableState>(vertical()).position.jumpTo(0);
    await t.pump(const Duration(milliseconds: 400));
    await t.scrollUntilVisible(
      finder,
      280,
      scrollable: vertical(),
      maxScrolls: 60,
    );
  } else {
    await t.ensureVisible(finder.first);
  }
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester t, Finder finder) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      await reveal(t, finder);
      final center = t.getCenter(finder.first);
      await t.tapAt(center);
      break;
    } on StateError {
      if (attempt == 3) rethrow;
      await t.pump(const Duration(milliseconds: 400));
    }
  }
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> fill(WidgetTester t, String id, String value) async {
  await reveal(t, key(id));
  await t.enterText(key(id), value);
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> nav(WidgetTester t, int index) async {
  await t.tap(find.byType(NavigationDestination).at(index));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> passed(String id, String evidence) async {
  cases.add({'case': id, 'result': 'PASS', 'evidence': evidence});
  await control('/control', {'action': 'stage', 'name': 'PASS $id: $evidence'});
}

void main() {
  final binding = AcceptanceBinding();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets('Customer acceptance on Android with real local services', (
    t,
  ) async {
    final f = object(await control('/fixture'));
    await app.main();
    await t.pump(const Duration(seconds: 2));
    final store = t.widget<OrganicApp>(find.byType(OrganicApp)).store;
    bool surfaceConverted = false;
    Future<void> shot(String name) async {
      if (!surfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        surfaceConverted = true;
      }
      await t.pump();
      await binding.takeScreenshot('${f['phase']}-$name');
    }

    Future<void> login() async {
      await nav(t, 4);
      await tap(t, find.text('Đăng nhập / Đăng ký'));
      await fill(t, 'auth.username', '${f['username']}');
      await fill(t, 'auth.password', '${f['password']}');
      await tap(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      await waitFor(t, find.text('Góc nhỏ của bạn'));
    }

    Future<void> product() async {
      await nav(t, 1);
      await fill(t, 'catalog.search', '${f['productName']}');
      await t.pump(const Duration(seconds: 1));
      await waitFor(t, find.text('${f['productName']}'));
      await tap(t, key('product.tile.${f['productId']}'));
      await waitFor(t, find.text('${f['productName']}'));
      await reveal(t, key('product.add'));
    }

    Future<void> addTwo() async {
      await product();
      await tap(t, key('product.variant.${f['variantId']}'));
      await tap(t, key('product.increase'));
      await tap(t, key('product.add'));
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (store.cartCount != 2 && DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(store.cartCount, 2);
      await back(t);
      await nav(t, 2);
    }

    Future<void> checkout({bool discount = false}) async {
      await tap(t, find.text('Tiến hành đặt hàng'));
      await waitFor(t, key('checkout.receiverName'));
      await fill(t, 'checkout.receiverName', 'Khach nghiem thu');
      await fill(t, 'checkout.receiverPhone', '0901234567');
      await fill(t, 'checkout.shippingAddress', '123 Duong Nghiem Thu, TP HCM');
      if (discount) {
        await fill(t, 'checkout.promotionCode', '${f['promotionCode']}');
        await fill(t, 'checkout.points', '1');
      }
      await tap(t, find.text('Kiểm tra giá & tồn kho'));
      await waitFor(t, find.text('Tổng thanh toán'));
      await reveal(t, find.text('Xác nhận đặt hàng'));
      await waitFor(t, find.text('Xác nhận đặt hàng'));
      expect(find.text(discount ? '178.000 đ' : '200.000 đ'), findsWidgets);
    }

    try {
      if (f['phase'] == 'restore') {
        expect(
          store.loggedIn,
          true,
          reason: 'Secure session survived Android process restart',
        );
        await store.refreshAccount();
        await t.pump();
        await nav(t, 4);
        await waitFor(t, find.text('Sang nghiem thu'));
        expect(store.readUpdates, isNotEmpty);
        await passed(
          'AUTH03-PERSIST',
          'Session, profile, and read notifications restored after force-stop/relaunch',
        );
        await shot('restored-profile');
        await tap(t, find.text('Đăng xuất'));
        await tap(t, find.widgetWithText(FilledButton, 'Đăng xuất'));
        await waitFor(t, find.text('Đăng nhập / Đăng ký'));
        expect(store.cartItems, isEmpty);
        expect(store.orders, isEmpty);
        await passed(
          'AUTH04',
          'UI logout clears account, cart, orders and saved session',
        );
      } else if (f['phase'] == 'loggedout') {
        expect(store.loggedIn, false);
        await passed(
          'AUTH04-PERSIST',
          'Logged-out state survives force-stop/relaunch',
        );
      } else if (f['phase'] == 'otp') {
        if (store.loggedIn) await store.logout();
        await nav(t, 4);
        await tap(t, find.text('Đăng nhập / Đăng ký'));
        await tap(t, find.text('Đã đăng ký? Xác thực email'));
        await fill(t, 'register.email', '${f['email']}');
        await tap(t, find.text('Gửi lại mã OTP'));
        await waitFor(
          t,
          find.text('Đã yêu cầu gửi lại mã. Vui lòng kiểm tra email.'),
        );
        String? otp;
        final end = DateTime.now().add(const Duration(minutes: 8));
        while (otp == null && DateTime.now().isBefore(end)) {
          final result = object(await control('/otp'));
          if (result['ready'] == true) {
            otp = '${result['otp']}';
          } else {
            await t.pump(const Duration(seconds: 2));
          }
        }
        expect(otp, isNotNull);
        await fill(t, 'register.otp', otp == '000000' ? '111111' : '000000');
        await tap(t, find.text('Xác thực tài khoản'));
        await waitFor(
          t,
          find.textContaining('Mã OTP không đúng hoặc đã hết hạn'),
        );
        await fill(t, 'register.otp', otp!);
        await tap(t, find.text('Xác thực tài khoản'));
        await waitFor(t, key('auth.username'));
        await passed(
          'AUTH02-VERIFY',
          'Native resume-verification screen sent real OTP; wrong code rejected, Gmail code activated account',
        );
        await shot('verified');
        await back(t);
      } else if (f['phase'] == 'retry' || f['phase'] == 'finish') {
        expect(store.loggedIn, true);
        if (f['phase'] == 'retry') {
          expect(store.pendingCheckout, isNotNull);
          await nav(t, 2);
          await tap(t, find.text('Tiến hành đặt hàng'));
          await reveal(t, find.text('Thử lại đơn này'));
          await control('/control', {'action': 'web_cart', 'quantity': 3});
          await tap(t, find.text('Thử lại đơn này'));
          await waitFor(t, find.text('Chi tiết đơn hàng'), seconds: 60);
          final events = objects(await control('/events'));
          final posts = events
              .where(
                (e) =>
                    e['type'] == 'request' &&
                    e['method'] == 'POST' &&
                    e['path'] == '/api/v1/orders' &&
                    e['status'] == 201,
              )
              .toList();
          final matching = posts
              .where((e) => e['idempotencyKey'] == posts.last['idempotencyKey'])
              .toList();
          expect(matching.length, 2);
          expect(matching.map((e) => e['orderId']).toSet().length, 1);
          expect(store.cartCount, 3);
          await passed(
            'ORDER03-CART02-CONCURRENT',
            'Saved uncertain checkout restored after app restart; same key returns the same order, newer web cart preserved',
          );
        } else {
          await store.refreshAccount(force: true);
          await t.pump();
          await nav(t, 3);
          final order = store.orders.firstWhere(
            (o) => o['status'] == 'confirmed',
          );
          await tap(t, find.text('${order['orderCode']}'));
          await waitFor(t, find.text('Chi tiết đơn hàng'));
        }
        await t.pump(const Duration(seconds: 6));
        await tap(t, find.text('Hủy đơn hàng'));
        await tap(t, find.widgetWithText(FilledButton, 'Hủy đơn'));
        await waitFor(t, find.text('Đã hủy'));
        await back(t);
        await nav(t, 2);
        await tap(t, find.byTooltip('Bỏ sản phẩm khỏi giỏ'));
        await waitFor(t, find.text('Giỏ hàng còn đang trống'));
        await passed('CART01-REMOVE', 'Native remove emptied the cart');
        await nav(t, 4);
        await tap(t, find.text('Cập nhật đơn hàng'));
        await waitFor(t, find.text('Tin từ Mộc'));
        await tap(t, find.text('Đã hủy').first);
        await waitFor(t, find.text('Chi tiết đơn hàng'));
        expect(store.readUpdates, isNotEmpty);
        await shot('order-recovered');
        await back(t);
        await back(t);
        await passed(
          'NOTICE01',
          'Foreground order update opened detail and saved read marker',
        );
        await control('/control', {
          'action': 'fault',
          'faults': [
            {'kind': 'unauthorized', 'method': 'GET', 'path': '/api/v1/cart'},
          ],
        });
        await store.refreshAccount(force: true);
        await t.pump();
        expect(store.loggedIn, true);
        await control('/control', {
          'action': 'fault',
          'faults': [
            {'kind': 'unauthorized', 'method': 'GET', 'path': '/api/v1/cart'},
            {
              'kind': 'disconnect',
              'method': 'POST',
              'path': '/api/v1/auth/refresh-token',
            },
          ],
        });
        await store.refreshAccount(force: true);
        await t.pump();
        expect(store.loggedIn, true);
        expect(store.accountError, isNotNull);
        await store.refreshAccount(force: true);
        await t.pump();
        expect(store.accountError, isNull);
        await passed(
          'AUTH03-REFRESH-FAILURE01',
          'Real refresh rotates tokens; simulated refresh network loss retains session and recovers',
        );
        final summary = object(
          await control('/control', {'action': 'summary'}),
        );
        expect(summary['staffStatus'], 403);
        await passed(
          'AUTH01-AUTHORIZATION',
          'Customer management endpoint HTTP403',
        );
      } else if (f['phase'] == 'extra') {
        if (!store.loggedIn) await login();
        await store.loadCategories();
        await t.pump();
        await nav(t, 1);
        await control('/control', {
          'action': 'fault',
          'faults': [
            {
              'kind': 'unavailable',
              'method': 'GET',
              'path': '/api/v1/products',
            },
          ],
        });
        await fill(t, 'catalog.search', '${f['productName']}');
        await waitFor(t, find.text('Chưa tải được sản phẩm'));
        await tap(t, find.text('Thử lại'));
        await t.pump(const Duration(seconds: 1));
        await reveal(t, find.text('1 sản phẩm đã tải'));
        await waitFor(t, find.text('1 sản phẩm đã tải'));
        await fill(t, 'catalog.search', '');
        await waitFor(t, find.text('20 sản phẩm đã tải'));
        await tap(t, find.text('Mới nhất'));
        await tap(t, find.text('Tên A–Z').last);
        await t.pump(const Duration(seconds: 2));
        await reveal(t, key('catalog.search'));
        await waitFor(t, find.text('Rau nghiệm thu'));
        final categoryChip = find.text('Rau nghiệm thu');
        await t.ensureVisible(categoryChip);
        await t.pump();
        await tap(t, categoryChip);
        await waitFor(t, find.text('15 sản phẩm đã tải'));
        final events = objects(await control('/events'));
        final catalogEvents = events
            .where((e) => e['path'] == '/api/v1/products' && e['status'] == 200)
            .toList();
        expect(
          object(catalogEvents.last['query'])['categoryId'],
          f['categoryId'],
        );
        expect(object(catalogEvents.last['query'])['sortBy'], 'productName');
        expect(object(catalogEvents.last['query'])['direction'], 'asc');
        await passed(
          'CAT01-FILTER-FAILURE01',
          'Native catalog retries a simulated503; category and alphabetical sort reach the real API',
        );
        await control('/control', {'action': 'pagination_orders'});
        await store.refreshAccount();
        await t.pump();
        expect(store.hasMoreOrders, true);
        await nav(t, 3);
        await tap(t, find.text('Xem đơn cũ hơn'));
        final end = DateTime.now().add(const Duration(seconds: 40));
        while (store.hasMoreOrders && DateTime.now().isBefore(end)) {
          await t.pump(const Duration(milliseconds: 250));
        }
        expect(store.hasMoreOrders, false);
        expect(
          store.orders.map((o) => o['id']).toSet().length,
          store.orders.length,
        );
        expect(store.orders.length, greaterThan(20));
        await passed(
          'ORDER-PAGINATION',
          '21 isolated fixture orders allow native load-more; all orders loaded without duplicates',
        );
        await control('/control', {'action': 'cleanup_pagination_orders'});
        final privateCode = '${store.orders.first['orderCode']}';
        await tap(t, find.text(privateCode));
        await waitFor(t, find.text('Chi tiết đơn hàng'));
        await control('/control', {'action': 'revoke'});
        await store.refreshAccount();
        await t.pump();
        expect(store.loggedIn, false);
        expect(store.cart, isNull);
        expect(store.orders, isEmpty);
        await waitFor(t, find.text('Phiên đăng nhập đã thay đổi'));
        expect(find.text(privateCode), findsNothing);
        await tap(t, find.text('Về trang chính'));
        await nav(t, 4);
        await waitFor(t, find.text('Đăng nhập / Đăng ký'));
        await passed(
          'AUTH03-REVOKED',
          'Actual backend session revocation rejects refresh and clears private data on Android',
        );
        await login();
        await passed(
          'AUTH03-RECOVERY',
          'Native login restores the customer after server-side revocation',
        );
        await nav(t, 4);
        await tap(t, find.text('Cập nhật đơn hàng'));
        await tap(t, find.text('${store.orders.first['orderCode']}'));
        await waitFor(t, find.text('Chi tiết đơn hàng'));
        await back(t);
        await back(t);
      } else {
        if (!store.loggedIn &&
            f['registrationComplete'] != true &&
            f['phase'] == 'core') {
          await nav(t, 2);
          await tap(t, find.text('Đăng nhập / Đăng ký'));
          await tap(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
          expect(find.text('Nhập tên đăng nhập.'), findsOneWidget);
          await fill(t, 'auth.username', 'customer');
          await fill(t, 'auth.password', 'incorrect-password');
          await tap(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
          await waitFor(
            t,
            find.textContaining('Tên đăng nhập, mật khẩu không đúng'),
          );
          await fill(t, 'auth.username', 'admin');
          await fill(t, 'auth.password', 'Organic@123');
          await tap(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
          await waitFor(t, find.textContaining('Ứng dụng dành cho khách hàng'));
          await passed(
            'AUTH01',
            'Empty/wrong credentials and staff login rejected in native UI',
          );
          await tap(t, find.text('Chưa có tài khoản? Đăng ký cùng Mộc'));
          for (final e in {
            'fullName': 'Khach nghiem thu',
            'username': '${f['username']}',
            'phoneNumber': '0901234567',
            'email': '${f['email']}',
            'password': '${f['password']}',
            'confirmPassword': '${f['password']}',
          }.entries) {
            await fill(t, 'register.${e.key}', e.value);
          }
          await tap(t, find.text('Tạo tài khoản'));
          await waitFor(t, find.text('Xác thực email'), seconds: 90);
          await shot('otp-waiting');
          String? otp;
          final end = DateTime.now().add(const Duration(minutes: 12));
          while (otp == null && DateTime.now().isBefore(end)) {
            final result = object(await control('/otp'));
            if (result['ready'] == true) {
              otp = '${result['otp']}';
            } else {
              await t.pump(const Duration(seconds: 2));
            }
          }
          expect(
            otp,
            isNotNull,
            reason: 'OTP must arrive in the authorized Gmail inbox',
          );
          await fill(t, 'register.otp', otp == '000000' ? '111111' : '000000');
          await tap(t, find.text('Xác thực tài khoản'));
          await waitFor(
            t,
            find.textContaining('Mã OTP không đúng hoặc đã hết hạn'),
          );
          await fill(t, 'register.otp', otp!);
          await tap(t, find.text('Xác thực tài khoản'));
          await waitFor(t, key('auth.username'));
          await passed(
            'AUTH02',
            'Registration sent a real email; wrong OTP rejected and Gmail OTP activated account',
          );
          await back(t);
        }
        if (!store.loggedIn) await login();
        await store.refreshAccount();
        await t.pump();
        // Prepare only this isolated account for a repeatable test run.
        for (final item in [...store.cartItems]) {
          await store.quantity('${item['variantId']}', 0);
        }
        final initialPoints = number(store.rewards?['available']);
        if (f['phase'] != 'orders') {
          await nav(t, 1);
          await fill(t, 'catalog.search', 'khong-co-san-pham-uat');
          await t.pump(const Duration(seconds: 1));
          await waitFor(t, find.text('Chưa tìm thấy sản phẩm'));
          await fill(t, 'catalog.search', '');
          await t.pump(const Duration(seconds: 1));
          await waitFor(t, find.text('20 sản phẩm đã tải'));
          await tap(t, find.text('Xem thêm sản phẩm'));
          await t.pump(const Duration(seconds: 2));
          await reveal(t, find.text('23 sản phẩm đã tải'));
          await waitFor(t, find.text('23 sản phẩm đã tải'));
          await passed(
            'CAT02',
            'Native catalog loads 20 then 23 products without losing the first page',
          );
          await fill(t, 'catalog.search', '${f['productName']}');
          await t.pump(const Duration(seconds: 1));
          await waitFor(t, find.text('1 sản phẩm đã tải'));
          await tap(t, key('product.tile.${f['productId']}'));
          await waitFor(t, find.text('${f['productName']}'));
          await reveal(t, key('product.add'));
          await tap(t, key('product.variant.${f['emptyVariantId']}'));
          final disabled = t.widget<FilledButton>(key('product.add'));
          expect(disabled.onPressed, isNull);
          await passed(
            'CAT01-CAT03',
            'Vietnamese search, empty result, detail, variant selection, zero-stock purchase disabled',
          );
          await back(t);
          await nav(t, 4);
          await tap(t, find.text('Thông tin cá nhân'));
          await fill(t, 'profile.dateOfBirth', '2026-02-31');
          await tap(t, find.text('Lưu thông tin'));
          expect(find.text('Nhập ngày theo yyyy-MM-dd.'), findsOneWidget);
          await fill(t, 'profile.dateOfBirth', '2005-01-01');
          await fill(t, 'profile.fullName', 'Sang nghiem thu');
          await tap(t, find.text('Lưu thông tin'));
          await waitFor(t, find.text('Góc nhỏ của bạn'));
          await waitFor(t, find.text('Sang nghiem thu'));
          await tap(t, find.text('Địa chỉ nhận hàng'));
          await tap(t, find.text('Thêm địa chỉ'));
          for (final e in {
            'label': 'Nha UAT',
            'receiverName': 'Khach nghiem thu',
            'receiverPhone': '0901234567',
            'province': 'TP HCM',
            'district': 'Tan Phu',
            'ward': 'Tay Thanh',
            'streetAddress': '123 Duong Nghiem Thu',
          }.entries) {
            await fill(t, 'address.${e.key}', e.value);
          }
          await tap(t, find.text('Đặt làm địa chỉ mặc định'));
          await tap(t, find.text('Lưu địa chỉ'));
          await waitFor(t, find.text('Nha UAT · Mặc định'));
          await passed(
            'PROFILE01',
            'Invalid calendar date rejected; profile and default shipping address saved through UI',
          );
          await back(t);
        }
        await addTwo();
        await tap(t, find.byTooltip('Tăng số lượng'));
        await t.pump(const Duration(seconds: 2));
        expect(store.cartCount, 3);
        await tap(t, find.byTooltip('Giảm số lượng'));
        await t.pump(const Duration(seconds: 2));
        expect(store.cartCount, 2);
        final webCart = object(
          await control('/control', {'action': 'web_cart', 'quantity': 3}),
        );
        expect(number(webCart['totalQuantity']), 3);
        await store.refreshAccount();
        await t.pump();
        expect(store.cartCount, 3);
        await tap(t, find.byTooltip('Giảm số lượng'));
        await t.pump(const Duration(seconds: 2));
        final webAfter = object(
          await control('/control', {'action': 'web_cart'}),
        );
        expect(number(webAfter['totalQuantity']), 2);
        await passed(
          'CART01-CART02',
          'Add/increase/decrease in Android; bidirectional cart sync through real Vite web proxy',
        );
        await checkout();
        await shot('checkout-cod');
        await tap(t, find.text('Xác nhận đặt hàng'));
        await waitFor(t, find.text('Chi tiết đơn hàng'), seconds: 60);
        await waitFor(t, find.text('Đã xác nhận'));
        final first = store.orders.first;
        final orderId = first['id'];
        expect(number(object(first['pricing'])['totalAmount']), 200000);
        expect(store.cartCount, 0);
        await passed(
          'ORDER01-ORDER02',
          'Native COD preview and confirm created one 200000 VND order and cleared cart',
        );
        for (final step in ['prepare', 'deliver', 'complete']) {
          await control('/control', {
            'action': 'staff',
            'step': step,
            'orderId': orderId,
          });
          await tap(t, find.byTooltip('Cập nhật trạng thái'));
          await waitFor(
            t,
            find.text(
              {
                'prepare': 'Đang chuẩn bị',
                'deliver': 'Đã giao hàng',
                'complete': 'Hoàn tất',
              }[step]!,
            ),
          );
        }
        expect(find.text('Hủy đơn hàng'), findsNothing);
        await store.refreshAccount();
        await t.pump();
        expect(number(store.rewards?['available']), initialPoints + 2);
        expect(store.transactions, isNotEmpty);
        await passed(
          'ORDER04-REWARD01',
          'UI followed prepare/delivery/completion; completed order earned exactly 2 points and cannot be cancelled',
        );
        await shot('completed-order');
        await back(t);
        await addTwo();
        await checkout(discount: true);
        await tap(t, find.text('Xác nhận đặt hàng'));
        await waitFor(t, find.text('Chi tiết đơn hàng'), seconds: 60);
        await waitFor(t, find.text('Đã xác nhận'));
        expect(number(store.rewards?['reserved']), 1);
        await tap(t, find.text('Hủy đơn hàng'));
        await tap(t, find.widgetWithText(FilledButton, 'Hủy đơn'));
        await waitFor(t, find.text('Đã hủy'));
        expect(number(store.rewards?['reserved']), 0);
        expect(number(store.rewards?['available']), initialPoints + 2);
        await passed(
          'ORDER05-REWARD02-REWARD03',
          '10% promotion plus 1 point yields 178000 VND; cancellation releases reserved point',
        );
        await back(t);
        await addTwo();
        await checkout();
        await control('/control', {
          'action': 'fault',
          'faults': [
            {
              'kind': 'disconnect_after_commit',
              'method': 'POST',
              'path': '/api/v1/orders',
            },
          ],
        });
        await tap(t, find.text('Xác nhận đặt hàng'));
        await waitFor(t, find.textContaining('Chưa xác nhận được kết quả'));
        await reveal(t, find.text('Thử lại đơn này'));
        await waitFor(t, find.text('Thử lại đơn này'));
        await back(t);
        await control('/control', {'action': 'web_cart', 'quantity': 3});
        await tap(t, find.text('Tiến hành đặt hàng'));
        await reveal(t, find.text('Thử lại đơn này'));
        await waitFor(t, find.text('Thử lại đơn này'));
        await tap(t, find.text('Thử lại đơn này'));
        await waitFor(t, find.text('Chi tiết đơn hàng'), seconds: 60);
        final events = objects(await control('/events'));
        final posts = events
            .where(
              (e) =>
                  e['type'] == 'request' &&
                  e['method'] == 'POST' &&
                  e['path'] == '/api/v1/orders' &&
                  e['status'] == 201,
            )
            .toList();
        final lastKey = posts.last['idempotencyKey'];
        final duplicates = posts
            .where((e) => e['idempotencyKey'] == lastKey)
            .toList();
        expect(duplicates.length, 2);
        expect(duplicates.map((e) => e['orderId']).toSet().length, 1);
        expect(store.cartCount, 3);
        await passed(
          'CART02-CONCURRENT',
          'Web quantity changed after order commit; conditional cleanup preserved the newer cart',
        );
        await passed(
          'ORDER03',
          'TCP response dropped after commit; retry reused key and returned the same order ID',
        );
        await tap(t, find.text('Hủy đơn hàng'));
        await tap(t, find.widgetWithText(FilledButton, 'Hủy đơn'));
        await waitFor(t, find.text('Đã hủy'));
        await back(t);
        await nav(t, 2);
        await tap(t, find.byTooltip('Bỏ sản phẩm khỏi giỏ'));
        await waitFor(t, find.text('Giỏ hàng còn đang trống'));
        await passed('CART01-REMOVE', 'Native remove action empties the cart');
        await nav(t, 4);
        await tap(t, find.text('Điểm xanh & ưu đãi'));
        await waitFor(t, find.text('Lịch sử điểm'));
        await shot('rewards');
        await back(t);
        await tap(t, find.text('Cập nhật đơn hàng'));
        await waitFor(t, find.text('Tin từ Mộc'));
        await tap(t, find.text('Đã hủy').first);
        await waitFor(t, find.text('Chi tiết đơn hàng'));
        expect(store.readUpdates, isNotEmpty);
        await back(t);
        await back(t);
        await passed(
          'NOTICE01',
          'Order updates open detail and persist a read marker; this is foreground polling, not push',
        );
        await control('/control', {
          'action': 'fault',
          'faults': [
            {'kind': 'unauthorized', 'method': 'GET', 'path': '/api/v1/cart'},
          ],
        });
        await store.refreshAccount();
        await t.pump();
        expect(store.loggedIn, true);
        await passed(
          'AUTH03-REFRESH',
          'One simulated expired access response triggered real backend token refresh and preserved session',
        );
        await control('/control', {
          'action': 'fault',
          'faults': [
            {'kind': 'unauthorized', 'method': 'GET', 'path': '/api/v1/cart'},
            {
              'kind': 'disconnect',
              'method': 'POST',
              'path': '/api/v1/auth/refresh-token',
            },
          ],
        });
        await store.refreshAccount();
        await t.pump();
        expect(store.loggedIn, true);
        expect(store.accountError, isNotNull);
        await store.refreshAccount();
        await t.pump();
        expect(store.accountError, isNull);
        await passed(
          'FAILURE01',
          'Network failure during refresh shows retryable error; account survives and recovers',
        );
        final summary = object(
          await control('/control', {'action': 'summary'}),
        );
        expect(summary['staffStatus'], 403);
        await passed(
          'AUTH01-AUTHORIZATION',
          'Backend rejects customer access to management orders with HTTP403',
        );
        await shot('account-final');
      }
      binding.reportData = {
        ...?binding.reportData,
        'phase': f['phase'],
        'cases': cases,
      };
      await control('/result', {
        'phase': f['phase'],
        'cases': cases,
        'success': true,
      });
    } catch (error, stack) {
      binding.reportData = {
        ...?binding.reportData,
        'phase': f['phase'],
        'cases': cases,
        'failure': '$error',
        'stack': '$stack',
      };
      await control('/result', {
        'phase': f['phase'],
        'cases': cases,
        'failure': '$error',
        'stack': '$stack',
        'success': false,
      });
      await shot('failure');
      rethrow;
    } finally {
      store.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 35)));
}
