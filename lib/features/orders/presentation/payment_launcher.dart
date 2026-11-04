import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../domain/payment_policy.dart';

typedef PaymentUrlOpener = Future<bool> Function(Uri url, LaunchMode mode);

Future<void> openPaymentPortal(Json payment, {PaymentUrlOpener? opener}) async {
  final url = paymentRedirect(payment);
  final open =
      opener ?? (Uri url, LaunchMode mode) => launchUrl(url, mode: mode);
  final mode = payment['gateway'] == 'payos'
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;
  Future<bool> tryOpen(LaunchMode mode) async {
    try {
      return await open(url, mode);
    } on PlatformException {
      return false;
    }
  }

  var opened = await tryOpen(mode);
  if (!opened && mode == LaunchMode.inAppBrowserView) {
    opened = await tryOpen(LaunchMode.externalApplication);
  }
  if (!opened) {
    throw const ApiException(
      'Chưa mở được trang thanh toán. Vui lòng thử lại từ chi tiết đơn hàng.',
    );
  }
}
