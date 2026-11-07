import '../../../app/state/organic_store.dart';
import '../../../core/utils/json.dart';
import '../../address/domain/vietnam_address.dart';

Json? cartCheckoutPayload(OrganicStore store, {String voucher = ''}) {
  final profile = store.profile;
  final addresses = objects(profile?['addresses']);
  final address =
      addresses.where((a) => a['isDefault'] == true).firstOrNull ??
      addresses.firstOrNull;
  if (address == null) return null;
  final name = '${address['receiverName'] ?? profile?['fullName'] ?? ''}'
      .trim();
  final phone = '${address['receiverPhone'] ?? profile?['phoneNumber'] ?? ''}'
      .trim();
  final street = savedAddressText(address);
  return validVoucherRecipient({
    'items': store.cartItems
        .map((i) => {'variantId': i['variantId'], 'quantity': i['quantity']})
        .toList(),
    'receiverName': name,
    'receiverPhone': phone,
    'shippingAddress': street,
    'paymentMethod': 'cod',
    'points': 0,
    'note': '',
    'promotionCode': store.selectedPromotionCode.isEmpty
        ? null
        : store.selectedPromotionCode,
    'voucherCode': voucher.isEmpty ? null : voucher,
  });
}

Json? validVoucherRecipient(Json? body) {
  if (body == null) return null;
  final name = '${body['receiverName'] ?? ''}'.trim();
  final phone = '${body['receiverPhone'] ?? ''}'.trim();
  final street = '${body['shippingAddress'] ?? ''}'.trim();
  if (name.isEmpty ||
      name.length > 100 ||
      street.isEmpty ||
      street.length > 500 ||
      !RegExp(r'^[+0-9 ()-]{8,20}$').hasMatch(phone) ||
      objects(body['items']).isEmpty) {
    return null;
  }
  return {
    ...body,
    'receiverName': name,
    'receiverPhone': phone,
    'shippingAddress': street,
    'points': 0,
  };
}
