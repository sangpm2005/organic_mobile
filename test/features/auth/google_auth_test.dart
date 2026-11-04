import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/core/network/organic_api.dart';
import 'package:organic_mobile/features/auth/data/google_auth_repository.dart';
import 'package:organic_mobile/features/auth/data/google_identity.dart';

const googleClient = 'web-client.apps.googleusercontent.com';
final nonce = 'n' * 43, challengeCookie = 'c' * 43;

class FakeGoogleIdentity implements GoogleIdentity {
  final Future<String?> Function(String clientId, String nonce) choose;
  FakeGoogleIdentity(this.choose);
  @override
  bool get supported => true;
  @override
  Future<String?> authenticate({
    required String clientId,
    required String nonce,
  }) => choose(clientId, nonce);
}

http.Response envelope(
  dynamic data, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode({
    'data': data,
    'message': status == 401 ? 'Mật khẩu chưa đúng' : 'OK',
  }),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

http.Response challenge({String? cookie, String? nextNonce}) => envelope(
  {'clientId': googleClient, 'nonce': nextNonce ?? nonce, 'expiresIn': 300},
  headers: cookie == null
      ? {}
      : {
          'set-cookie':
              'organic_google_auth=$cookie; Path=/api/v1/auth/google; Max-Age=300; HttpOnly; SameSite=Lax',
        },
);

const loginData = {
  'accessToken': 'app-access',
  'refreshToken': 'app-refresh',
  'user': {
    'accountId': 'google-account',
    'roles': ['CUSTOMER'],
    'fullName': 'Khách Google',
    'profileCompletionRequired': true,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('uses server client ID and nonce, echoes only the challenge cookie, and stores app JWTs', () async {
    final requests = <http.Request>[];
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/challenge')) {
          return challenge(cookie: challengeCookie);
        }
        if (request.url.path.endsWith('/auth/google')) {
          return envelope(loginData);
        }
        if (request.url.path.endsWith('/customers/me')) {
          return envelope({'fullName': 'Khách Google', 'phoneNumber': null});
        }
        return envelope({'items': [], 'totalElements': 0});
      }),
    );
    final store = OrganicStore(
      api: api,
      googleIdentity: FakeGoogleIdentity((client, serverNonce) async {
        expect(client, googleClient);
        expect(serverNonce, nonce);
        return 'google-id-token';
      }),
    );
    expect(await store.loginWithGoogle(), isTrue);
    expect(store.api.accessToken, 'app-access');
    expect(store.profileCompletionRequired, isTrue);
    final post = requests.firstWhere(
      (r) => r.url.path.endsWith('/auth/google'),
    );
    expect(post.headers['Cookie'], 'organic_google_auth=$challengeCookie');
    expect(post.headers['Authorization'], isNull);
    expect(post.followRedirects, isFalse);
    expect(jsonDecode(post.body), {
      'credential': 'google-id-token',
      'rememberMe': true,
    });
    final saved = await store.storage.read(key: 'moc.session.v1');
    expect(saved, contains('app-refresh'));
    expect(saved, isNot(contains('google-id-token')));
    expect(saved, isNot(contains(challengeCookie)));
    store.dispose();
  });

  test('cancel and retry create fresh challenges without reusing Google credentials', () async {
    var attempt = 0, exchanges = 0, nativeCalls = 0;
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) {
          attempt++;
          return challenge(cookie: '$attempt' * 43, nextNonce: '$attempt' * 43);
        }
        exchanges++;
        expect(request.headers['Cookie'], 'organic_google_auth=${'2' * 43}');
        return envelope(loginData);
      }),
    );
    final auth = GoogleAuthRepository(
      api,
      identity: FakeGoogleIdentity((_, serverNonce) async {
        nativeCalls++;
        expect(serverNonce, '$nativeCalls' * 43);
        return nativeCalls == 1 ? null : 'second-google-token';
      }),
    );
    expect(await auth.login(isCurrent: () => true), isNull);
    expect(exchanges, 0);
    expect(await auth.login(isCurrent: () => true), loginData);
    expect(attempt, 2);
    expect(exchanges, 1);
  });

  test(
    'missing nonce cookie never opens Google or posts credentials',
    () async {
      var posts = 0;
      final api = OrganicApi(
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((_) async {
          posts++;
          return challenge();
        }),
      );
      final auth = GoogleAuthRepository(
        api,
        identity: FakeGoogleIdentity(
          (_, _) async => throw StateError('Must not open Google'),
        ),
      );
      await expectLater(
        auth.login(isCurrent: () => true),
        throwsA(isA<ApiException>()),
      );
      expect(posts, 1);
    },
  );

  test('a duplicate tap cannot overwrite the first attempt nonce', () async {
    final selected = Completer<String?>(), opened = Completer<void>();
    var challengeCalls = 0;
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) {
          challengeCalls++;
          return challenge(cookie: challengeCookie);
        }
        return envelope(loginData);
      }),
    );
    final auth = GoogleAuthRepository(
      api,
      identity: FakeGoogleIdentity((_, _) {
        opened.complete();
        return selected.future;
      }),
    );
    final pending = auth.login(isCurrent: () => true);
    await opened.future;
    await expectLater(
      auth.login(isCurrent: () => true),
      throwsA(isA<ApiException>()),
    );
    selected.complete('google-id-token');
    await pending;
    expect(challengeCalls, 1);
  });

  test(
    'logout during Google selection prevents a stale login request',
    () async {
      final selected = Completer<String?>(), opened = Completer<void>();
      var exchangeCalls = 0;
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/challenge')) {
              return challenge(cookie: challengeCookie);
            }
            if (request.url.path.endsWith('/auth/google')) exchangeCalls++;
            return envelope({});
          }),
        ),
        googleIdentity: FakeGoogleIdentity((_, _) {
          opened.complete();
          return selected.future;
        }),
      );
      final pending = store.loginWithGoogle();
      await opened.future;
      await store.logout();
      selected.complete('google-id-token');
      expect(await pending, isFalse);
      expect(exchangeCalls, 0);
      expect(store.loggedIn, isFalse);
      store.dispose();
    },
  );

  test(
    'staff Google accounts cannot become mobile customer sessions',
    () async {
      final store = OrganicStore(
        api: OrganicApi(
          baseUrl: 'http://localhost/api/v1',
          client: MockClient(
            (r) async => r.url.path.endsWith('/challenge')
                ? challenge(cookie: challengeCookie)
                : envelope({
                    ...loginData,
                    'user': {
                      'roles': ['STAFF'],
                    },
                  }),
          ),
        ),
        googleIdentity: FakeGoogleIdentity((_, _) async => 'google-id-token'),
      );
      await expectLater(store.loginWithGoogle(), throwsA(isA<ApiException>()));
      expect(store.loggedIn, isFalse);
      expect(store.api.accessToken, isNull);
      store.dispose();
    },
  );

  test('incorrect link password preserves the existing app session', () async {
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) {
          expect(request.headers['Authorization'], 'Bearer existing-access');
          return challenge(cookie: challengeCookie);
        }
        if (request.url.path.endsWith('/customers/me')) {
          return envelope({'phoneNumber': '0900000000'});
        }
        expect(request.url.path, '/api/v1/auth/google/link');
        expect(
          request.headers['Cookie'],
          'organic_google_auth=$challengeCookie',
        );
        expect(request.headers['Authorization'], 'Bearer existing-access');
        expect(jsonDecode(request.body), {
          'credential': 'google-id-token',
          'currentPassword': 'wrong-password',
        });
        return envelope(null, status: 401);
      }),
    );
    api.setSession('existing-access', 'existing-refresh');
    final auth = GoogleAuthRepository(
      api,
      identity: FakeGoogleIdentity((_, _) async => 'google-id-token'),
    );
    await expectLater(
      auth.link(currentPassword: 'wrong-password', isCurrent: () => true),
      throwsA(isA<ApiException>()),
    );
    expect(api.accessToken, 'existing-access');
    expect(api.refreshToken, 'existing-refresh');
  });

  test('a Secure challenge cookie cannot be sent over HTTP', () async {
    final api = OrganicApi(
      baseUrl: 'http://localhost/api/v1',
      client: MockClient(
        (_) async => envelope(
          {'clientId': googleClient, 'nonce': nonce},
          headers: {
            'set-cookie':
                'organic_google_auth=$challengeCookie; Secure; HttpOnly',
          },
        ),
      ),
    );
    final auth = GoogleAuthRepository(
      api,
      identity: FakeGoogleIdentity(
        (_, _) async => throw StateError('Must not open Google'),
      ),
    );
    await expectLater(
      auth.login(isCurrent: () => true),
      throwsA(isA<ApiException>()),
    );
  });
}
