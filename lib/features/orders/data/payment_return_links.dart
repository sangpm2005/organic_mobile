import 'package:flutter/services.dart';

/// A return link is navigation only; OrderScreen reconciles with the server.
String? paymentReturnOrder(Uri uri) {
  if (uri.scheme != 'organicfood' ||
      uri.host != 'payment-return' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final ids = uri.queryParametersAll['orderId'];
  if (ids == null || ids.length != 1) return null;
  final id = ids.single;
  return RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)
      ? id
      : null;
}

class PaymentReturnLinks {
  static const channel = MethodChannel('vn.huit.organic_mobile/payment-return');
  bool disposed = false;
  Future<void> start(void Function(Uri) onLink) async {
    channel.setMethodCallHandler((call) async {
      if (!disposed && call.method == 'open' && call.arguments is String) {
        final uri = Uri.tryParse(call.arguments as String);
        if (uri != null) onLink(uri);
      }
    });
    try {
      final text = await channel.invokeMethod<String>('initialLink');
      if (!disposed && text != null) {
        final uri = Uri.tryParse(text);
        if (uri != null) onLink(uri);
      }
    } on MissingPluginException {
      /* Platforms without this Android bridge use resume reconciliation. */
    } on PlatformException {
      /* Navigation links are optional. */
    }
  }

  void dispose() {
    disposed = true;
    channel.setMethodCallHandler(null);
  }
}
