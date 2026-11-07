import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/utils/json.dart';
import '../domain/vietnam_address.dart';

class AddressDirectory {
  static VietnamAddresses? _data;
  static Future<VietnamAddresses>? _pending;

  static Future<VietnamAddresses> load() {
    final cached = _data;
    if (cached != null) return Future.value(cached);
    return _pending ??= _load();
  }

  static Future<VietnamAddresses> _load() async {
    try {
      final source = await rootBundle.loadString(
        'assets/data/address/vietnam.json',
      );
      final data = VietnamAddresses.fromJson(object(jsonDecode(source)));
      _data = data;
      return data;
    } finally {
      _pending = null;
    }
  }
}
