import 'package:intl/intl.dart';

import 'json.dart';

String money(dynamic value) {
  final amount = number(value);
  // Intl preserves the sign of -0.0, including negative amounts rounded to 0.
  final formatted = NumberFormat.decimalPattern('vi_VN')
      .format(amount == 0 ? 0 : amount);
  return '${formatted == '-0' ? '0' : formatted} đ';
}

String dateText(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null ? '—' : DateFormat('dd/MM/yyyy · HH:mm').format(parsed);
}
