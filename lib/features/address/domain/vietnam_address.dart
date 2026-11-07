import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

String addressText(String text) {
  var result = text.toLowerCase();
  const letters = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in letters.entries) {
    result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\btp\.?\s*'), 'thanh pho ')
      .replaceAll(RegExp(r'\bhcm\b'), 'ho chi minh')
      .replaceAllMapped(RegExp(r'\bq[.\s]*(\d+)'), (m) => 'quan ${m[1]}')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _simpleName(String text) => addressText(text)
    .replaceAll(RegExp(r'\b(thanh pho|tinh|phuong|xa|thi tran|dac khu)\b'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

bool _contains(String text, String phrase) =>
    phrase.isNotEmpty && ' $text '.contains(' $phrase ');

class AddressProvince {
  final String code, name;
  late final search = addressText(name);
  AddressProvince(this.code, this.name);
}

class AddressWard {
  final String code, name;
  final AddressProvince province;
  final List<List<String>> aliases;
  AddressWard(this.code, this.name, this.province, this.aliases);
  String get title => '$name, ${province.name}';
  late final normalizedName = _simpleName(name);
  late final normalizedTitle = _simpleName(title);
  late final aliasNames = aliases.map((a) => _simpleName(a[0])).toSet();
  late final districtKeys = aliases
      .where((a) => a.length > 1)
      .map((a) => _simpleName(a[1]))
      .where((v) => v.isNotEmpty)
      .toSet();
  late final historicalDistricts = aliases
      .where((a) => a.length > 1 && a[1].trim().isNotEmpty)
      .map((a) => a[1].trim())
      .toSet();
  late final search = _simpleName(
    [
      name,
      province.name,
      for (final alias in aliases) ...[
        alias[0],
        if (alias.length > 1) ...[
          'quan ${alias[1]}',
          'huyen ${alias[1]}',
          alias[1],
        ],
        if (alias.length > 2) alias[2],
      ],
    ].join(' '),
  );
  late final searchWords = search.split(' ');
}

class AddressDraft {
  final String provinceCode, wardCode, street;
  const AddressDraft({
    this.provinceCode = '',
    this.wardCode = '',
    this.street = '',
  });
  AddressDraft copyWith({
    String? provinceCode,
    String? wardCode,
    String? street,
  }) => AddressDraft(
    provinceCode: provinceCode ?? this.provinceCode,
    wardCode: wardCode ?? this.wardCode,
    street: street ?? this.street,
  );
}

class VietnamAddresses {
  final List<AddressProvince> provinces;
  final List<AddressWard> wards;
  final Json metadata;
  late final _provincesByCode = {for (final p in provinces) p.code: p};
  late final _wardsByCode = {for (final w in wards) w.code: w};
  late final _districtNames =
      wards.expand((w) => w.districtKeys).toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length));

  VietnamAddresses._(this.provinces, this.wards, this.metadata);

  factory VietnamAddresses.fromJson(Json data) {
    final provinces = objects(data['provinces'])
        .map((p) => AddressProvince('${p['code']}', '${p['name']}'))
        .toList();
    final byCode = {for (final p in provinces) p.code: p};
    final wards = objects(data['wards']).map((w) {
      final province = byCode[w['provinceCode']];
      if (province == null) {
        throw const FormatException('Invalid address province');
      }
      final aliases = (w['aliases'] as List? ?? [])
          .whereType<List>()
          .where((a) => a.isNotEmpty)
          .map((a) => a.map((v) => '$v').toList())
          .toList();
      return AddressWard('${w['code']}', '${w['name']}', province, aliases);
    }).toList();
    if (provinces.isEmpty ||
        wards.isEmpty ||
        byCode.length != provinces.length ||
        wards.map((w) => w.code).toSet().length != wards.length) {
      throw const FormatException('Invalid address directory');
    }
    return VietnamAddresses._(
      List.unmodifiable(provinces),
      List.unmodifiable(wards),
      object(data['metadata']),
    );
  }

  AddressProvince? province(String code) => _provincesByCode[code];
  AddressWard? selectedWard(AddressDraft value) {
    final ward = _wardsByCode[value.wardCode];
    return ward?.province.code == value.provinceCode ? ward : null;
  }

  List<AddressWard> wardsOf(String provinceCode) =>
      wards.where((w) => w.province.code == provinceCode).toList();

  List<AddressWard> search(
    String query, {
    String provinceCode = '',
    int limit = 8,
  }) {
    final normalized = _simpleName(query);
    if (normalized.length < 2 || limit <= 0) return [];
    final district = _districtNames
        .where(
          (name) =>
              _contains(normalized, 'quan $name') ||
              _contains(normalized, 'huyen $name'),
        )
        .firstOrNull;
    final tokens = normalized.split(' ');
    final results = wards.where((ward) {
      if (provinceCode.isNotEmpty && ward.province.code != provinceCode) {
        return false;
      }
      if (district != null && !ward.districtKeys.contains(district)) {
        return false;
      }
      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        if (!_contains(ward.search, token) &&
            !(i == tokens.length - 1 &&
                ward.searchWords.any((word) => word.startsWith(token)))) {
          return false;
        }
      }
      return true;
    }).toList();
    int score(AddressWard ward) => _contains(normalized, ward.normalizedName)
        ? 3
        : ward.aliasNames.any((name) => _contains(normalized, name))
        ? 2
        : 1;
    results.sort((a, b) {
      final rank = score(b).compareTo(score(a));
      return rank != 0 ? rank : a.title.compareTo(b.title);
    });
    return results.take(limit).toList();
  }

  AddressWard? exact(String text) {
    final normalized = _simpleName(text);
    final current = wards
        .where((w) => w.normalizedTitle == normalized)
        .toList();
    if (current.length == 1) return current.single;
    final results = search(text, limit: 2);
    if (results.length != 1) return null;
    final ward = results.single;
    return _contains(normalized, ward.normalizedName) ||
            ward.aliasNames.any((name) => _contains(normalized, name))
        ? ward
        : null;
  }

  AddressDraft fromSaved(Json address) {
    final ward = exact(
      [
        address['ward'],
        address['province'],
      ].where((v) => v != null && '$v'.trim().isNotEmpty).join(', '),
    );
    return AddressDraft(
      provinceCode: ward?.province.code ?? '',
      wardCode: ward?.code ?? '',
      street: '${address['streetAddress'] ?? ''}',
    );
  }

  AddressDraft fromShipping(String text) {
    final parts = text.split(',').map((p) => p.trim()).toList();
    for (final levels in [2, 3]) {
      if (parts.length <= levels) continue;
      final ward = exact(parts.sublist(parts.length - levels).join(', '));
      if (ward != null) {
        return AddressDraft(
          provinceCode: ward.province.code,
          wardCode: ward.code,
          street: parts.take(parts.length - levels).join(', '),
        );
      }
    }
    return AddressDraft(street: text.trim());
  }

  String shipping(AddressDraft value) {
    final ward = selectedWard(value);
    if (ward == null) {
      throw const ApiException(
        'Vui lòng chọn tỉnh/thành phố và phường/xã từ danh sách.',
      );
    }
    if (value.street.trim().isEmpty) {
      throw const ApiException('Vui lòng nhập số nhà, tên đường.');
    }
    final result = '${value.street.trim()}, ${ward.title}';
    if (result.length > 500) {
      throw const ApiException('Địa chỉ tối đa 500 ký tự.');
    }
    return result;
  }

  Json profileFields(AddressDraft value, {Json? previous}) {
    shipping(value);
    if (value.street.trim().length > 255) {
      throw const ApiException('Số nhà, tên đường tối đa 255 ký tự.');
    }
    final ward = selectedWard(value)!;
    final old = previous == null ? null : fromSaved(previous);
    final retained = '${previous?['district'] ?? ''}'.trim();
    final district =
        retained.isNotEmpty &&
            old?.provinceCode == value.provinceCode &&
            old?.wardCode == value.wardCode
        ? retained
        : ward.historicalDistricts.length == 1
        ? ward.historicalDistricts.single
        : '';
    if (district.isEmpty) {
      throw const ApiException(
        'Chưa thể lưu địa chỉ này. Vui lòng chọn lại tỉnh/thành phố và phường/xã; nếu vẫn gặp lỗi, hãy liên hệ cửa hàng.',
      );
    }
    return {
      'province': ward.province.name,
      'ward': ward.name,
      'district': district,
      'streetAddress': value.street.trim(),
    };
  }
}

String savedAddressText(Json address) =>
    [address['streetAddress'], address['ward'], address['province']]
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .map((v) => '$v'.trim())
        .join(', ');
