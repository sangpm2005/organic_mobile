import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'favorites persist for one account and remain separate after logout',
    () async {
      final store = customer(MockClient((r) async => response({})));
      await store.savePendingCheckout(null);
      await store.toggleFavorite('product-a');
      await store.toggleFavorite('product-b');
      await store.toggleFavorite('product-a');
      final restored = customer(MockClient((r) async => response([])));
      await restored.initialize();
      expect(restored.favorites, {'product-b'});
      await restored.logout();
      expect(restored.favorites, isEmpty);
      restored.dispose();
      store.dispose();
    },
  );
}
