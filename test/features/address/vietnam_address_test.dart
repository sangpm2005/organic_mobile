import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/features/address/domain/vietnam_address.dart';

void main() {
  final directory = VietnamAddresses.fromJson(
    jsonDecode(File('assets/data/address/vietnam.json').readAsStringSync()),
  );
  test('bundled directory has distinct provinces and valid ward parents', () {
    expect(directory.provinces.length, 34);
    expect(directory.wards.length, 3321);
    expect(directory.wards.map((w) => w.code).toSet().length, 3321);
    expect(
      directory.wards.every((w) => directory.province(w.province.code) != null),
      isTrue,
    );
    expect(directory.metadata, isNotEmpty);
  });
  test(
    'old names, accents and shorthand resolve to current two-level address',
    () {
      final ward = directory.exact('Phường Bến Nghé, Thành phố Hồ Chí Minh')!;
      expect(ward.name, 'Phường Sài Gòn');
      expect(directory.exact('Ben Nghe ho chi minh')?.code, ward.code);
      expect(
        directory.search('sai gon hcm').map((w) => w.code),
        contains(ward.code),
      );
      final district = directory.search('Q.1 TP.HCM', limit: 50);
      expect(district, isNotEmpty);
      expect(district.every((w) => w.districtKeys.contains('1')), isTrue);
      expect(directory.exact('Q.1 TP.HCM'), isNull);
      expect(directory.search('sai gon', provinceCode: '01'), isEmpty);
    },
  );
  test('saved and free-form legacy addresses preserve street and normalize selected levels', () {
    final draft = directory.fromSaved({
      'province': 'Hồ Chí Minh',
      'district': '1',
      'ward': 'Bến Nghé',
      'streetAddress': ' 12 Lê Lợi ',
    });
    expect(
      directory.shipping(draft),
      '12 Lê Lợi, Phường Sài Gòn, Thành phố Hồ Chí Minh',
    );
    expect(
      directory.fromShipping('12 Lê Lợi, Bến Nghé, Quận 1, TP.HCM').wardCode,
      draft.wardCode,
    );
    final formatted = directory.fromShipping(directory.shipping(draft));
    expect(formatted.wardCode, draft.wardCode);
    expect(formatted.street, '12 Lê Lợi');
    expect(directory.fromShipping('Địa chỉ chưa rõ').street, 'Địa chỉ chưa rõ');
    expect(directory.fromShipping('Địa chỉ chưa rõ').wardCode, isEmpty);
    expect(directory.selectedWard(draft.copyWith(provinceCode: '01')), isNull);
    expect(
      () => directory.shipping(draft.copyWith(street: ' ')),
      throwsA(isA<ApiException>()),
    );
  });
  test('address-book payload preserves compatibility without guessing ambiguous districts', () {
    final ward = directory.exact('Bến Nghé, Hồ Chí Minh')!;
    final draft = AddressDraft(
      provinceCode: ward.province.code,
      wardCode: ward.code,
      street: '12 Lê Lợi',
    );
    expect(directory.profileFields(draft), {
      'province': 'Thành phố Hồ Chí Minh',
      'ward': 'Phường Sài Gòn',
      'district': '1',
      'streetAddress': '12 Lê Lợi',
    });
    final ambiguous = directory.wards.firstWhere(
      (w) => w.historicalDistricts.length > 1,
    );
    final ambiguousDraft = AddressDraft(
      provinceCode: ambiguous.province.code,
      wardCode: ambiguous.code,
      street: '24 Đường A',
    );
    expect(directory.shipping(ambiguousDraft), contains(ambiguous.name));
    expect(
      () => directory.profileFields(ambiguousDraft),
      throwsA(isA<ApiException>()),
    );
    final old = {
      'province': ambiguous.province.name,
      'ward': ambiguous.name,
      'district': ambiguous.historicalDistricts.first,
    };
    expect(
      directory.profileFields(ambiguousDraft, previous: old)['district'],
      old['district'],
    );
    expect(directory.profileFields(draft, previous: old)['district'], '1');
    expect(
      savedAddressText({...old, 'streetAddress': '24 Đường A'}),
      '24 Đường A, ${ambiguous.name}, ${ambiguous.province.name}',
    );
  });
}
