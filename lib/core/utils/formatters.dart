import 'package:intl/intl.dart';

import 'json.dart';

String money(dynamic value) =>
    '${NumberFormat.decimalPattern('vi_VN').format(number(value))} đ';
String dateText(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null ? '—' : DateFormat('dd/MM/yyyy · HH:mm').format(parsed);
}
