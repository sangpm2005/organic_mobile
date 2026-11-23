import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/state/organic_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/theme/organic_theme.dart';
import '../../cart/data/cart_checkout_payload.dart';
import '../../catalog/domain/sale_selection.dart';
import '../domain/voucher_recommendation.dart';
import 'widgets/voucher_card.dart';

class VoucherPickerScreen extends StatefulWidget {
  final Json? checkoutPayload;
  const VoucherPickerScreen({super.key, this.checkoutPayload});
  @override
  State<VoucherPickerScreen> createState() => _VoucherPickerScreenState();
}

class _VoucherPickerScreenState extends State<VoucherPickerScreen> {
  OrganicStore? store;
  List<Json>? wallet;
  int? walletSession;
  List<VoucherRecommendation> rows = [];
  int revision = 0;
  String? signature, error;
  bool busy = true, verificationUnavailable = false;
  double subtotal = 0;

  String scope() => jsonEncode({
    'session': store!.api.sessionVersion,
    'cart': store!.cart,
    'profile': store!.profile,
    'promotion': store!.selectedPromotionCode,
    'checkout': widget.checkoutPayload,
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store = StoreScope.of(context);
    final next = scope();
    if (signature != next) {
      signature = next;
      load();
    }
  }

  Future<void> load({bool refresh = false}) async {
    final request = ++revision, version = store!.api.sessionVersion;
    final currentScope = scope();
    bool current() =>
        mounted &&
        request == revision &&
        version == store!.api.sessionVersion &&
        currentScope == scope();
    setState(() {
      busy = true;
      error = null;
      verificationUnavailable = false;
      rows = [];
    });
    try {
      final raw = widget.checkoutPayload ?? cartCheckoutPayload(store!);
      final body = validVoucherRecipient(raw);
      final selected = objects(raw?['items'] ?? store!.cart?['items']);
      final items = selected
          .map(
            (i) => {
              ...?store!.cartItems
                  .where((r) => saleKey(r) == saleKey(i))
                  .firstOrNull,
              ...i,
            },
          )
          .toList();
      subtotal = items.fold<double>(
        0,
        (sum, i) => sum + number(i['unitPrice']) * number(i['quantity']),
      );
      if (widget.checkoutPayload == null && store!.cart?['subtotal'] != null) {
        subtotal = number(store!.cart?['subtotal']);
      }
      if (walletSession != version) wallet = null;
      if (refresh || wallet == null) {
        final loaded = await store!.rewardService.allWallet(isCurrent: current);
        if (!current()) return;
        wallet = loaded;
        walletSession = version;
      }
      final ranked = wallet!
          .map((v) => VoucherRecommendation.forCart(v, items, subtotal))
          .toList();
      if (body != null) {
        var index = 0;
        Future<void> check() async {
          while (current() &&
              !verificationUnavailable &&
              index < ranked.length) {
            final position = index++, candidate = ranked[position];
            if (!candidate.fitsCart) continue;
            try {
              final quote = await store!.checkout.preview({
                ...body,
                'voucherCode': candidate.voucher['voucherCode'],
                'points': 0,
              });
              if (!current()) return;
              ranked[position] = candidate.checked(
                number(quote['voucherDiscount']),
              );
            } on ApiException catch (failure) {
              if (!current()) return;
              if ([400, 404, 409, 422].contains(failure.status) ||
                  failure.message.startsWith('Voucher chưa được áp dụng')) {
                ranked[position] = candidate.rejected();
              } else {
                verificationUnavailable = true;
              }
            }
          }
        }

        // Customer preview uses server locks: limit parallel requests.
        await Future.wait([check(), check()]);
      }
      if (!current()) return;
      ranked.sort(VoucherRecommendation.compare);
      setState(() {
        rows = ranked;
        busy = false;
      });
    } catch (failure) {
      if (current()) {
        setState(() {
          error = '$failure';
          busy = false;
        });
      }
    }
  }

  void select(VoucherRecommendation row) {
    if (busy) return;
    if (!row.fitsCart) {
      toast(context, 'Voucher không phù hợp với giỏ hàng hiện tại.');
      return;
    }
    Navigator.pop(context, row.voucher);
  }

  @override
  void dispose() {
    revision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn voucher')),
    body: RefreshIndicator(
      onRefresh: () => load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Giỏ hàng ${money(subtotal)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ưu tiên voucher phù hợp, sắp xếp theo số tiền giảm từ cao xuống thấp.',
          ),
          const SizedBox(height: 16),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => load(refresh: true),
              child: const Text('Thử lại'),
            ),
          ],
          if (!busy && error == null && rows.isEmpty)
            const Text('Chưa có voucher trong ví.'),
          if (verificationUnavailable)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Chưa kiểm tra được toàn bộ ưu đãi. Mức giảm dự kiến sẽ được xác nhận lại khi áp dụng.',
              ),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i == 0 || rows[i].fitsCart != rows[i - 1].fitsCart)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  rows[i].fitsCart
                      ? 'Ưu tiên cho giỏ hàng của bạn'
                      : 'Voucher khác',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            VoucherCard(
              rows[i].voucher,
              key: ValueKey('voucher.choice.${rows[i].voucher['voucherCode']}'),
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rows[i].fitsCart)
                    Text(
                      '${rows[i].verified ? 'Giảm' : 'Dự kiến giảm'} ${money(rows[i].saving)}',
                      style: const TextStyle(
                        color: moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (rows[i].voucher['usable'] == true)
                    TextButton(
                      onPressed: () => select(rows[i]),
                      child: const Text('Sử dụng'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
