import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/notifications/data/customer_push.dart';
import 'package:organic_mobile/features/notifications/data/push_gateway.dart';

import '../helpers/customer_fixtures.dart';

class FakePush extends PushGateway {
  bool permitted = true;
  int initializations = 0, permissions = 0, deletions = 0;
  Completer<String?>? tokenPending;
  final changes = StreamController<String>.broadcast();
  final messages = StreamController<PushEvent>.broadcast();
  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<bool> requestPermission() async {
    permissions++;
    return permitted;
  }

  @override
  Future<String?> token() async =>
      tokenPending == null ? 'device-a' : tokenPending!.future;
  @override
  Future<void> deleteToken() async {
    deletions++;
  }

  @override
  Stream<String> get tokens => changes.stream;
  @override
  Stream<PushEvent> get events => messages.stream;
  @override
  Future<PushEvent?> initialEvent() async => null;
  Future<void> close() async {
    await changes.close();
    await messages.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('customer destinations reject foreign URLs and admin routes', () {
    expect(
      notificationDestination({'target': '/don-hang/order-a'})?.id,
      'order-a',
    );
    expect(
      notificationDestination({'target': '/phan-hoi?feedbackId=feedback-a'})
          ?.kind,
      'phan-hoi',
    );
    expect(
      notificationDestination({'target': '/doi-tra?requestId=return-a'})?.id,
      'return-a',
    );
    for (final target in [
      'https://evil.example/don-hang/a',
      '//evil.example/don-hang/a',
      '/admin/orders/a',
      '/don-hang/%2Fadmin',
      '/don-hang/a#other',
    ]) {
      expect(notificationDestination({'target': target}), isNull);
    }
  });
  test('permission denied does not register a device', () async {
    var calls = 0;
    final api = OrganicApi(
      client: MockClient((r) async {
        calls++;
        return response(null);
      }),
    );
    api.setSession('access', 'refresh');
    final gateway = FakePush()..permitted = false;
    final push = CustomerPush(
      api,
      const FlutterSecureStorage(),
      () => 'a',
      gateway: gateway,
    );
    await push.restore();
    expect(gateway.initializations, 0);
    await push.enable();
    expect(calls, 0);
    expect(push.enabled, isFalse);
    expect(push.error, isNotNull);
    push.dispose();
    api.close();
    await gateway.close();
  });
  test('registers token, ignores another account, refreshes token and revokes on disable', () async {
    final calls = <String>[];
    final api = OrganicApi(
      client: MockClient((r) async {
        calls.add('${r.method}:${jsonDecode(r.body)['token']}');
        return response(null);
      }),
    );
    api.setSession('access', 'refresh');
    final gateway = FakePush();
    final push = CustomerPush(
      api,
      const FlutterSecureStorage(),
      () => 'a',
      gateway: gateway,
    );
    final events = <PushEvent>[];
    final subscription = push.events.listen(events.add);
    await push.enable();
    expect(push.enabled, isTrue);
    gateway.messages.add(
      const PushEvent({'type': 'CUSTOMER_INBOX', 'accountId': 'b'}),
    );
    gateway.messages.add(
      const PushEvent({
        'type': 'CUSTOMER_INBOX',
        'accountId': 'a',
        'target': '/don-hang/order-a',
      }),
    );
    gateway.changes.add('device-new');
    await Future<void>.delayed(Duration.zero);
    await push.disable();
    expect(events.length, 1);
    expect(calls, ['PUT:device-a', 'PUT:device-new', 'DELETE:device-new']);
    expect(gateway.deletions, 1);
    expect(push.enabled, isFalse);
    await subscription.cancel();
    push.dispose();
    api.close();
    await gateway.close();
  });
  test(
    'account switch while getting a token never binds it to the new account',
    () async {
      var calls = 0;
      var owner = 'a';
      final api = OrganicApi(
        client: MockClient((r) async {
          calls++;
          return response(null);
        }),
      );
      api.setSession('a', 'refresh');
      final gateway = FakePush()..tokenPending = Completer<String?>();
      final push = CustomerPush(
        api,
        const FlutterSecureStorage(),
        () => owner,
        gateway: gateway,
      );
      final enabling = push.enable();
      await Future<void>.delayed(Duration.zero);
      owner = 'b';
      api.setSession('b', 'refresh');
      push.sessionCleared();
      gateway.tokenPending!.complete('old-device');
      await enabling;
      expect(calls, 0);
      expect(push.enabled, isFalse);
      push.dispose();
      api.close();
      await gateway.close();
    },
  );
}
