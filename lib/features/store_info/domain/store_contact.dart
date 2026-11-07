import '../../../core/utils/json.dart';

/// Matches the public footer in organic_frontend/src/constants/footer.js and
/// its address in src/constants/store.js. API values override these defaults.
class StoreContact {
  static const defaults = <String, String>{
    'contactPhone': '028 7307 1088',
    'contactEmail': 'info@organicfood.vn',
    'contactAddress': '123 Đinh Tiên Hoàng, Quận 1, Thành phố Hồ Chí Minh',
    'openingHours': '7h – 20h · Thứ Hai đến Chủ Nhật',
  };

  static Json withDefaults(Json content) => {
    ...content,
    for (final entry in defaults.entries)
      entry.key: '${content[entry.key] ?? ''}'.trim().isEmpty
          ? entry.value
          : '${content[entry.key]}'.trim(),
  };
}
