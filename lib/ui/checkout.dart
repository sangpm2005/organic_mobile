import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'customer.dart';
import 'theme.dart';
import 'widgets.dart';

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
      'promotionCode',
      'points',
    ])
      k: TextEditingController(),
  };
  OrganicStore? store;
  List<Json> items = [];
  Json? quote;
  Json methods = {'cod': true};
  String method = 'cod', key = OrganicStore.newIdempotencyKey();
  String? error;
  bool busy = false, submitted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (store != null) {
      return;
    }
    store = StoreScope.of(context);
    items = store!.cartItems
        .map((e) => {'variantId': e['variantId'], 'quantity': e['quantity']})
        .toList();
    fields['receiverName']!.text = '${store!.profile?['fullName'] ?? ''}';
    fields['receiverPhone']!.text = '${store!.profile?['phoneNumber'] ?? ''}';
    fields['points']!.text = '0';
    final addresses = objects(store!.profile?['addresses']);
    final address =
        addresses.where((a) => a['isDefault'] == true).firstOrNull ??
        addresses.firstOrNull;
    if (address != null) {
      fields['receiverName']!.text =
          '${address['receiverName'] ?? fields['receiverName']!.text}';
      fields['receiverPhone']!.text =
          '${address['receiverPhone'] ?? fields['receiverPhone']!.text}';
      fields['shippingAddress']!.text = [
        address['streetAddress'],
        address['ward'],
        address['district'],
        address['province'],
      ].where((e) => e != null && '$e'.isNotEmpty).join(', ');
    }
    final pending = store!.pendingCheckout;
    if (pending != null) {
      final saved = object(pending['payload']);
      for (final entry in fields.entries) {
        entry.value.text = '${saved[entry.key] ?? ''}';
      }
      items = objects(saved['items']);
      method = '${saved['paymentMethod']}';
      key = '${pending['key']}';
      quote = object(pending['quote']);
      submitted = true;
    }
    loadMethods();
  }

  Future<void> loadMethods() async {
    try {
      final result = object(
        await store!.api.request('GET', '/payments/methods'),
      );
      if (mounted) {
        setState(() => methods = {...result, 'cod': true});
      }
    } catch (_) {
      /* COD works without external gateways. */
    }
  }

  Json payload() => {
    'items': items,
    for (final entry in fields.entries)
      if (entry.key != 'points')
        entry.key:
            entry.key == 'promotionCode' && entry.value.text.trim().isEmpty
            ? null
            : entry.value.text.trim(),
    'paymentMethod': method,
    'points': int.tryParse(fields['points']!.text) ?? 0,
  };
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
    if (!form.currentState!.validate() || items.isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = object(
        await store!.api.request('POST', '/checkout/preview', body: payload()),
      );
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
    if (quote == null || busy) {
      return;
    }
    setState(() {
      busy = true;
      submitted = true;
      error = null;
    });
    Json order;
    try {
      await store!.savePendingCheckout({
        'key': key,
        'payload': payload(),
        'quote': quote,
      });
      order = object(
        await store!.api.request(
          'POST',
          '/orders',
          body: payload(),
          idempotencyKey: key,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
          if (e is ApiException && e.status != null && e.status! < 500) {
            submitted = false;
            quote = null;
            key = OrganicStore.newIdempotencyKey();
          }
        });
        if (!submitted) await store!.savePendingCheckout(null);
      }
      return;
    }
    await store!.savePendingCheckout(null);
    String? paymentWarning;
    if (method != 'cod' &&
        number(object(order['pricing'])['totalAmount']) > 0) {
      try {
        final payment = object(
          await store!.api.request(
            'POST',
            '/payments/initiate',
            body: {'orderId': order['id'], 'gateway': method},
          ),
        );
        final url = Uri.tryParse('${payment['paymentUrl']}');
        if (url == null ||
            url.scheme != 'https' ||
            !await launchUrl(url, mode: LaunchMode.externalApplication)) {
          paymentWarning = 'Đơn đã tạo. Chưa mở được cổng thanh toán; bạn có thể mở lại từ chi tiết đơn.';
        }
      } catch (_) {
        paymentWarning =
            'Đơn đã tạo. Vui lòng thử thanh toán lại từ chi tiết đơn.';
      }
    }
    for (final item in items) {
      try {
        await store!.quantity(
          '${item['variantId']}',
          0,
          expectedQuantity: (item['quantity'] as num).toInt(),
        );
        if (store!.cartItems.any((i) => i['variantId'] == item['variantId'])) {
          paymentWarning = 'Đơn đã tạo. Giỏ hàng đã được thay đổi trên thiết bị khác và được giữ lại; hãy kiểm tra trước khi mua tiếp.';
        }
      } catch (_) {
        paymentWarning ??= 'Đơn đã tạo. Chưa đồng bộ được giỏ hàng; hãy kiểm tra giỏ trước khi mua tiếp.';
      }
    }
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
      appBar: AppBar(title: const Text('Đặt hàng cùng Mộc')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Một bước nữa,\nlành đến tận nhà.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          Form(
            key: form,
            onChanged: invalidate,
            child: Column(
              children: [
                for (final entry in {
                  'receiverName': 'Người nhận',
                  'receiverPhone': 'Số điện thoại',
                  'shippingAddress': 'Địa chỉ giao hàng',
                  'note': 'Ghi chú (không bắt buộc)',
                  'promotionCode': 'Mã khuyến mãi (nếu có)',
                  'points': 'Điểm muốn sử dụng',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: ValueKey('checkout.${entry.key}'),
                      controller: fields[entry.key],
                      enabled: !busy && !submitted,
                      keyboardType:
                          ['points', 'receiverPhone'].contains(entry.key)
                          ? TextInputType.phone
                          : TextInputType.text,
                      maxLines: entry.key == 'shippingAddress' ? 2 : 1,
                      decoration: InputDecoration(labelText: entry.value),
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
                        if (entry.key == 'points') {
                          final points = int.tryParse(v);
                          if (points == null || points < 0 || points > 50) {
                            return 'Nhập số nguyên từ 0 đến 50.';
                          }
                          if (points > number(store!.rewards?['available'])) {
                            return 'Bạn chưa có đủ điểm khả dụng.';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Bạn có ${store!.rewards?['available'] ?? 0} điểm khả dụng. 1 điểm đổi ${money(store!.rewards?['redeemValue'] ?? 2000)}.',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 22),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(
              labelText: 'Phương thức thanh toán',
            ),
            items: [
              for (final e in {
                'cod': 'Thanh toán khi nhận hàng (COD)',
                'vnpay': 'VNPay',
                'stripe': 'Thẻ quốc tế (Stripe)',
                'paypal': 'PayPal',
              }.entries)
                if (methods[e.key] == true)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)),
                  ),
            ],
            onChanged: busy || submitted
                ? null
                : (v) {
                    method = v!;
                    invalidate();
                  },
          ),
          const SizedBox(height: 20),
          if (quote != null)
            Panel(
              child: Column(
                children: [
                  AmountRow('Tiền hàng', quote!['subtotal']),
                  AmountRow('Khuyến mãi', -number(quote!['promotionDiscount'])),
                  AmountRow('Đổi điểm', -number(quote!['pointsDiscount'])),
                  AmountRow('Phí giao hàng', quote!['shippingFee']),
                  const Divider(),
                  AmountRow(
                    'Tổng thanh toán',
                    quote!['totalAmount'],
                    total: true,
                  ),
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
            onPressed: busy
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
