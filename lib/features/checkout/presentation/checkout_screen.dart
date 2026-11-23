import 'package:flutter/material.dart';
import 'package:organic_mobile/app/state/organic_store.dart';
import 'package:organic_mobile/core/network/api_exception.dart';
import 'package:organic_mobile/core/utils/formatters.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/orders/presentation/order_screen.dart';
import 'package:organic_mobile/features/address/domain/vietnam_address.dart';
import 'package:organic_mobile/features/address/presentation/address_picker_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/features/rewards/presentation/voucher_picker_screen.dart';

import 'widgets/delivery_location_picker.dart';
import '../../store_info/domain/store_contact.dart';
import '../../catalog/domain/sale_selection.dart';
import '../../catalog/presentation/widgets/sale_option_picker.dart';
import 'widgets/price_summary.dart';

import 'package:organic_mobile/shared/widgets/panel.dart';
import 'package:organic_mobile/shared/widgets/session_boundary.dart';

import '../../orders/presentation/payment_launcher.dart';
import 'widgets/payment_methods.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in [
      'receiverName',
      'receiverPhone',
      'shippingAddress',
      'note',
      'invoiceEmail',
      'promotionCode',
      'voucherCode',
      'points',
    ])
      k: TextEditingController(),
  };
  OrganicStore? store;
  int? sessionVersion;
  bool get sameSession =>
      store?.loggedIn == true && store!.api.sessionVersion == sessionVersion;
  List<Json> items = [];
  Json? quote;
  Json? frozenPayload;
  Json? location;
  Json methods = {'cod': true};
  String method = 'cod', key = OrganicStore.newIdempotencyKey();
  String? error;
  bool busy = false, submitted = false, locating = false, pickup = false;
  int locationRequest = 0;
  String? locationMessage;
  String deliveryAddress = '';
  static const pickupPrefix =
      '[Yêu cầu nhận tại cửa hàng] Cần cửa hàng xác nhận lịch nhận.';
  String orderNote() => [
    if (pickup) pickupPrefix,
    if (fields['invoiceEmail']!.text.trim().isNotEmpty)
      'Email nhận hóa đơn (yêu cầu): ${fields['invoiceEmail']!.text.trim()}',
    fields['note']!.text.trim(),
  ].where((v) => v.isNotEmpty).join('\n');

  Future<void> resolveAddress() async {
    if (!sameSession || submitted || busy) return;
    final address = fields['shippingAddress']!.text.trim();
    final request = ++locationRequest;
    if (address.isEmpty) return;
    setState(() {
      locating = true;
      location = null;
      locationMessage = 'Đang xác định vị trí nhận hàng…';
    });
    try {
      final found = await store!.checkout.locations(address);
      if (!mounted ||
          !sameSession ||
          request != locationRequest ||
          submitted ||
          busy ||
          fields['shippingAddress']!.text.trim() != address) {
        return;
      }
      final precise = found.where((p) => p['precise'] == true).toList();
      setState(() {
        if (found.length == 1 && precise.length == 1) {
          location = precise.single;
          locationMessage = 'Đã xác định vị trí nhận hàng. Bạn có thể kiểm tra hoặc chọn lại.';
        } else {
          locationMessage = 'Có nhiều vị trí hoặc địa chỉ chưa rõ. Hãy xác nhận điểm nhận hàng.';
        }
      });
      invalidate();
    } catch (_) {
      if (mounted && request == locationRequest) {
        setState(
          () => locationMessage = 'Chưa xác định được vị trí. Bạn có thể dùng liên kết bản đồ hoặc tọa độ.',
        );
      }
    } finally {
      if (mounted && request == locationRequest) {
        setState(() => locating = false);
      }
    }
  }

  void changeFulfillment(bool value) {
    if (busy || submitted) return;
    if (value) deliveryAddress = fields['shippingAddress']!.text;
    pickup = value;
    fields['shippingAddress']!.text = value
        ? StoreContact.defaults['contactAddress']!
        : deliveryAddress;
    location = null;
    invalidate();
    resolveAddress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (store != null) {
      return;
    }
    store = StoreScope.of(context);
    sessionVersion = store!.api.sessionVersion;
    items = store!.cartItems.map(saleItem).toList();
    fields['receiverName']!.text = '${store!.profile?['fullName'] ?? ''}';
    fields['receiverPhone']!.text = '${store!.profile?['phoneNumber'] ?? ''}';
    fields['points']!.text = '0';
    fields['voucherCode']!.text = store!.selectedVoucherCode;
    fields['promotionCode']!.text = store!.selectedPromotionCode;
    final addresses = objects(store!.profile?['addresses']);
    final address =
        addresses.where((a) => a['isDefault'] == true).firstOrNull ??
        addresses.firstOrNull;
    if (address != null) {
      fields['receiverName']!.text =
          '${address['receiverName'] ?? fields['receiverName']!.text}';
      fields['receiverPhone']!.text =
          '${address['receiverPhone'] ?? fields['receiverPhone']!.text}';
      fields['shippingAddress']!.text = savedAddressText(address);
    }
    final pending = store!.pendingCheckout;
    if (pending != null) {
      final saved = object(pending['payload']);
      frozenPayload = saved;
      pickup = '${saved['note'] ?? ''}'.startsWith(pickupPrefix);
      for (final entry in fields.entries) {
        entry.value.text = '${saved[entry.key] ?? ''}';
      }
      final savedNote = '${saved['note'] ?? ''}';
      final emailLine = RegExp(
        r'^Email nhận hóa đơn \(yêu cầu\): (.+)$',
        multiLine: true,
      ).firstMatch(savedNote);
      if (emailLine != null) fields['invoiceEmail']!.text = emailLine[1]!;
      fields['note']!.text = savedNote
          .split('\n')
          .where(
            (line) =>
                line != pickupPrefix &&
                !line.startsWith('Email nhận hóa đơn (yêu cầu): '),
          )
          .join('\n');
      items = objects(saved['items']);
      method = '${saved['paymentMethod']}';
      key = '${pending['key']}';
      quote = object(pending['quote']);
      if (saved['deliveryLatitude'] != null &&
          saved['deliveryLongitude'] != null) {
        location = {
          'latitude': saved['deliveryLatitude'],
          'longitude': saved['deliveryLongitude'],
        };
      }
      submitted = true;
    }
    loadMethods();
    if (!submitted && fields['shippingAddress']!.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) resolveAddress();
      });
    }
  }

  Future<void> loadMethods() async {
    try {
      final result = await store!.checkout.methods();
      if (mounted) {
        setState(() => methods = {...result, 'cod': true});
      }
    } catch (_) {
      /* COD works without external gateways. */
    }
  }

  Json payload() =>
      frozenPayload ??
      {
        'items': items,
        for (final entry in fields.entries)
          if (!['points', 'invoiceEmail'].contains(entry.key))
            entry.key:
                ['promotionCode', 'voucherCode'].contains(entry.key) &&
                    entry.value.text.trim().isEmpty
                ? null
                : ['promotionCode', 'voucherCode'].contains(entry.key)
                ? entry.value.text.trim().toUpperCase()
                : entry.value.text.trim(),
        'note': orderNote(),
        'paymentMethod': method,
        'points': int.tryParse(fields['points']!.text) ?? 0,
        'deliveryLatitude': location?['latitude'],
        'deliveryLongitude': location?['longitude'],
      };
  Future<void> chooseLocation() async {
    final address = fields['shippingAddress']!.text;
    final result = await Navigator.of(context).push<Json>(
      MaterialPageRoute(
        builder: (_) =>
            SessionBoundary(child: DeliveryLocationPicker(address: address)),
      ),
    );
    if (result == null ||
        !mounted ||
        !sameSession ||
        submitted ||
        fields['shippingAddress']!.text != address) {
      return;
    }
    locationRequest++;
    locating = false;
    location = result;
    locationMessage = 'Đã chọn vị trí nhận hàng.';
    invalidate();
  }

  Future<void> chooseAddress() async {
    if (busy || submitted || !sameSession || pickup) return;
    final result = await open<String>(
      context,
      AddressPickerScreen(initialAddress: fields['shippingAddress']!.text),
      account: true,
    );
    if (result == null || !mounted || !sameSession || submitted || busy) return;
    fields['shippingAddress']!.text = result;
    location = null;
    invalidate();
    await resolveAddress();
  }

  Future<void> chooseVoucher() async {
    final voucher = await open<Json>(
      context,
      VoucherPickerScreen(checkoutPayload: payload()),
      account: true,
    );
    if (voucher == null || !mounted) return;
    fields['voucherCode']!.text = '${voucher['voucherCode']}';
    store!.selectVoucher('${voucher['voucherCode']}');
    fields['points']!.text = '0';
    invalidate();
  }

  void invalidate() {
    if (!submitted) {
      setState(() {
        quote = null;
        error = null;
        key = OrganicStore.newIdempotencyKey();
      });
    }
  }

  Future<void> preview() async {
    if (locating || !form.currentState!.validate() || items.isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await store!.checkout.preview(payload());
      if (mounted) {
        setState(() => quote = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> create() async {
    if (quote == null || busy || locating || !sameSession) {
      return;
    }
    setState(() {
      busy = true;
      submitted = true;
      error = null;
    });
    Json order;
    try {
      frozenPayload ??= payload();
      await store!.savePendingCheckout({
        'key': key,
        'payload': payload(),
        'quote': quote,
      });
      if (!sameSession) return;
      order = await store!.checkout.place(payload(), key);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
          if (e is ApiException &&
              e.status != null &&
              e.status! < 500 &&
              e.status != 408 &&
              e.status != 429) {
            submitted = false;
            frozenPayload = null;
            quote = null;
            key = OrganicStore.newIdempotencyKey();
          }
        });
        if (!submitted) await store!.savePendingCheckout(null);
      }
      return;
    }
    if (!sameSession) return;
    await store!.savePendingCheckout(null);
    if (!sameSession) return;
    store!.selectVoucher('');
    store!.selectPromotion('');
    String? paymentWarning;
    if (method != 'cod' &&
        number(object(order['pricing'])['totalAmount']) > 0) {
      try {
        final payment = await store!.orderService.initiate(
          '${order['id']}',
          method,
        );
        if (!sameSession) return;
        if (mounted) {
          toast(
            context,
            'Sau khi thanh toán, quay lại ứng dụng để xem kết quả đã được xác nhận.',
          );
        }
        await openPaymentPortal(payment);
      } catch (e) {
        paymentWarning =
            'Đơn đã tạo. $e Bạn có thể thử lại trong chi tiết đơn hàng.';
      }
    }
    for (final item in items) {
      if (!sameSession) return;
      try {
        await store!.quantity(
          saleKey(item),
          0,
          expectedQuantity: (item['quantity'] as num).toInt(),
        );
        if (store!.cartItems.any((i) => saleKey(i) == saleKey(item))) {
          paymentWarning = 'Đơn đã tạo. Giỏ hàng đã được thay đổi trên thiết bị khác và được giữ lại; hãy kiểm tra trước khi mua tiếp.';
        }
      } catch (_) {
        paymentWarning ??= 'Đơn đã tạo. Chưa đồng bộ được giỏ hàng; hãy kiểm tra giỏ trước khi mua tiếp.';
      }
    }
    if (!sameSession) return;
    await store!.refreshAccount(force: true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionBoundary(child: OrderScreen('${order['id']}')),
        ),
      );
      if (paymentWarning != null) {
        toast(context, paymentWarning);
      }
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt hàng cùng organicfood')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Một bước nữa,\nlành đến tận nhà.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          SwitchListTile.adaptive(
            title: const Text('Yêu cầu nhận tại cửa hàng'),
            subtitle: Text(
              pickup
                  ? '${StoreContact.defaults['contactAddress']}\nCửa hàng sẽ xác nhận lịch nhận với bạn.'
                  : 'Giao hàng đến địa chỉ của bạn',
            ),
            value: pickup,
            onChanged: busy || submitted ? null : changeFulfillment,
          ),
          Form(
            key: form,
            onChanged: invalidate,
            child: Column(
              children: [
                TextFormField(
                  controller: fields['invoiceEmail'],
                  enabled: !busy && !submitted,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => invalidate(),
                  decoration: const InputDecoration(
                    labelText: 'Email nhận hóa đơn (tùy chọn)',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v!.trim())
                      ? 'Email chưa hợp lệ.'
                      : null,
                ),
                const SizedBox(height: 16),
                for (final entry in {
                  'receiverName': 'Người nhận',
                  'receiverPhone': 'Số điện thoại',
                  'shippingAddress': 'Địa chỉ giao hàng',
                  'note': 'Ghi chú (không bắt buộc)',
                  'promotionCode': 'Mã khuyến mãi (nếu có)',
                  'voucherCode': 'Mã voucher trong ví (nếu có)',
                  'points': 'Điểm muốn sử dụng',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: ValueKey('checkout.${entry.key}'),
                      controller: fields[entry.key],
                      readOnly: entry.key == 'shippingAddress',
                      onTap: entry.key == 'shippingAddress'
                          ? chooseAddress
                          : null,
                      onChanged: (value) {
                        if (entry.key == 'shippingAddress') location = null;
                        if (entry.key == 'voucherCode' &&
                            value.trim().isNotEmpty) {
                          fields['points']!.text = '0';
                        }
                        if (entry.key == 'voucherCode') {
                          store!.selectVoucher(value);
                        }
                        if (entry.key == 'points' &&
                            (int.tryParse(value) ?? 0) > 0) {
                          fields['voucherCode']!.clear();
                          store!.selectVoucher('');
                        }
                        invalidate();
                      },
                      enabled: !busy && !submitted,
                      keyboardType:
                          ['points', 'receiverPhone'].contains(entry.key)
                          ? TextInputType.phone
                          : TextInputType.text,
                      maxLines: entry.key == 'shippingAddress' ? null : 1,
                      decoration: InputDecoration(
                        labelText: entry.value,
                        hintText: entry.key == 'shippingAddress'
                            ? 'Chọn tỉnh/thành phố, phường/xã và số nhà'
                            : null,
                        suffixIcon: entry.key == 'shippingAddress'
                            ? const Icon(Icons.expand_more)
                            : null,
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if ([
                              'receiverName',
                              'receiverPhone',
                              'shippingAddress',
                            ].contains(entry.key) &&
                            v.isEmpty) {
                          return 'Vui lòng nhập ${entry.value.toLowerCase()}.';
                        }
                        if (entry.key == 'receiverPhone' &&
                            !RegExp(r'^[+0-9 ()-]{8,20}$').hasMatch(v)) {
                          return 'Số điện thoại chưa hợp lệ.';
                        }
                        if (entry.key == 'receiverName' && v.length > 100 ||
                            entry.key == 'shippingAddress' && v.length > 500) {
                          return 'Nội dung quá dài.';
                        }
                        if (entry.key == 'note' && orderNote().length > 5000) {
                          return 'Ghi chú và email nhận hóa đơn tối đa 5.000 ký tự.';
                        }
                        if (entry.key == 'points') {
                          final points = int.tryParse(v);
                          final limit = number(
                            store!.rewards?['redeemLimit'] ?? 50,
                          ).clamp(0, 50).toInt();
                          if (points == null || points < 0 || points > limit) {
                            return 'Nhập số nguyên từ 0 đến $limit.';
                          }
                          if (points > number(store!.rewards?['available'])) {
                            return 'Bạn chưa có đủ điểm khả dụng.';
                          }
                          if (points > 0 && store!.rewards == null) {
                            return 'Chưa tải được số dư điểm. Vui lòng cập nhật lại.';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (locationMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(locationMessage!),
            ),
          if (locating) const LinearProgressIndicator(),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: busy || submitted ? null : chooseLocation,
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  location == null
                      ? 'Xác nhận vị trí giao hàng'
                      : 'Đã chọn vị trí giao hàng',
                ),
              ),
              TextButton.icon(
                onPressed: busy || submitted ? null : chooseVoucher,
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Chọn từ ví voucher'),
              ),
            ],
          ),
          Text(
            'Bạn có ${store!.rewards?['available'] ?? 0} điểm khả dụng. 1 điểm đổi ${money(store!.rewards?['redeemValue'] ?? 2000)}.',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 22),
          PaymentMethods(
            available: methods,
            value: method,
            enabled: !busy && !submitted,
            onChanged: (value) {
              method = value;
              invalidate();
            },
          ),
          const SizedBox(height: 20),
          if (quote != null)
            Panel(
              child: Column(
                children: [
                  for (final item in items) ...[
                    Builder(
                      builder: (context) {
                        final row =
                            objects(quote!['items'])
                                .where((r) => saleKey(r) == saleKey(item))
                                .firstOrNull ??
                            store!.cartItems
                                .where((r) => saleKey(r) == saleKey(item))
                                .firstOrNull ??
                            {};
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${row['productName'] ?? 'Sản phẩm đã chọn'} × ${item['quantity']}',
                          ),
                          subtitle: SaleExpiry(item['expiryDate']),
                        );
                      },
                    ),
                  ],
                  PriceSummary(quote!),
                  Text(
                    'Dự kiến tích ${quote!['estimatedEarnedPoints']} điểm khi đơn hoàn tất.',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          if (submitted && !busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: Text(
                'Chưa xác nhận được kết quả. Thử lại cùng đơn này để kiểm tra, hoặc xem danh sách đơn hàng.',
                style: TextStyle(color: muted),
              ),
            ),
          FilledButton.icon(
            onPressed: busy || locating
                ? null
                : quote == null
                ? preview
                : create,
            icon: Icon(
              busy
                  ? Icons.hourglass_empty
                  : quote == null
                  ? Icons.receipt_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(
              busy
                  ? 'Đang xử lý…'
                  : quote == null
                  ? 'Kiểm tra giá & tồn kho'
                  : submitted
                  ? 'Thử lại đơn này'
                  : 'Xác nhận đặt hàng',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Giá, ưu đãi và tồn kho được máy chủ kiểm tra lại khi xác nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
