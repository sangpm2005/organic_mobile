import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:organic_mobile/features/account/presentation/address_form.dart';
import 'package:organic_mobile/features/address/data/address_directory.dart';
import 'package:organic_mobile/features/address/domain/vietnam_address.dart';
import 'package:organic_mobile/features/address/presentation/widgets/structured_address_fields.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';

import '../../helpers/customer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VietnamAddresses directory;
  setUpAll(() async => directory = await AddressDirectory.load());
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'keyword and dropdown searches select two levels and clear ward when province changes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var value = const AddressDraft(street: '12 Lê Lợi');
      await tester.pumpWidget(
        MaterialApp(
          theme: organicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Form(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StructuredAddressFields(
                      directory: directory,
                      value: value,
                      onChanged: (next) => setState(() => value = next),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('address.search')),
        'ben nghe ho chi minh',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('address.suggestion.26740')));
      await tester.pumpAndSettle();
      expect(value.provinceCode, '79');
      expect(value.wardCode, '26740');
      expect(value.street, '12 Lê Lợi');
      await tester.ensureVisible(
        find.byKey(const ValueKey('address.province')),
      );
      await tester.tap(find.byKey(const ValueKey('address.province')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('address.options.search')),
        'ha noi',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('address.option.79')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('address.option.01')));
      await tester.pumpAndSettle();
      expect(value.provinceCode, '01');
      expect(value.wardCode, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('address.ward')));
      await tester.tap(find.byKey(const ValueKey('address.ward')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('address.options.search')),
        'ba dinh',
      );
      await tester.pumpAndSettle();
      final ward = directory
          .wardsOf('01')
          .firstWhere((w) => w.name == 'Phường Ba Đình');
      await tester.tap(find.byKey(ValueKey('address.option.${ward.code}')));
      await tester.pumpAndSettle();
      expect(value.wardCode, ward.code);
      expect(value.street, '12 Lê Lợi');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing a saved legacy address submits canonical ward and province with retained district',
    (tester) async {
      Map<String, dynamic>? saved;
      final store = customer(
        MockClient((r) async {
          if (r.method == 'PUT') {
            expect(r.url.path, endsWith('/addresses/address-a'));
            saved = jsonDecode(r.body);
          }
          return response({});
        }),
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: organicTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddressForm(
                        address: {
                          'id': 'address-a',
                          'label': 'Nhà',
                          'receiverName': 'Nguyễn An',
                          'receiverPhone': '0901234567',
                          'province': 'Hồ Chí Minh',
                          'district': '1',
                          'ward': 'Bến Nghé',
                          'streetAddress': '12 Lê Lợi',
                          'isDefault': true,
                        },
                      ),
                    ),
                  ),
                  child: const Text('Mở địa chỉ'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở địa chỉ'));
      await tester.pumpAndSettle();
      expect(find.text('Phường Sài Gòn'), findsOneWidget);
      expect(find.text('Quận / Huyện'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Lưu địa chỉ'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu địa chỉ'));
      await tester.pumpAndSettle();
      expect(saved, {
        'label': 'Nhà',
        'receiverName': 'Nguyễn An',
        'receiverPhone': '0901234567',
        'province': 'Thành phố Hồ Chí Minh',
        'ward': 'Phường Sài Gòn',
        'district': '1',
        'streetAddress': '12 Lê Lợi',
        'isDefault': true,
      });
      expect(find.text('Mở địa chỉ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
