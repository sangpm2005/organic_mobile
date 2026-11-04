import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

const _hosts = {
  'payos': ['pay.payos.vn'],
  'stripe': ['checkout.stripe.com'],
  'paypal': [
    'www.paypal.com',
    'www.sandbox.paypal.com',
    'paypal.com',
    'sandbox.paypal.com',
  ],
  'vnpay': ['sandbox.vnpayment.vn', 'pay.vnpay.vn', 'vnpayment.vn'],
};

Uri paymentRedirect(Json payment) {
  final url = Uri.tryParse('${payment['paymentUrl']}');
  if (payment['status'] != 'pending' ||
      url == null ||
      url.scheme != 'https' ||
      url.userInfo.isNotEmpty ||
      !(_hosts[payment['gateway']] ?? []).contains(url.host)) {
    throw const ApiException(
      'Chưa thể mở trang thanh toán. Vui lòng mở chi tiết đơn hàng để kiểm tra và thử lại.',
    );
  }
  return url;
}

bool canCancelOrder(Json order) =>
    order['paymentMethod'] != 'exchange' &&
    ['pending_payment', 'confirmed'].contains(order['status']) &&
    ![
      'paid',
      'partially_refunded',
      'refunded',
      'requires_review',
    ].contains(order['paymentStatus']);

bool canPayOrder(Json order) =>
    order['paymentMethod'] != 'exchange' &&
    order['status'] == 'pending_payment' &&
    ![
      'paid',
      'partially_refunded',
      'refunded',
      'requires_review',
    ].contains(order['paymentStatus']);
