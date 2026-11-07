import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/state/organic_store.dart';
import '../../../../core/utils/json.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/navigation/navigation.dart';
import '../../../../shared/state/store_scope.dart';
import '../../../../shared/theme/organic_theme.dart';
import '../../../../shared/widgets/amount_row.dart';
import '../../../auth/presentation/widgets/login_gate.dart';
import '../../../checkout/presentation/widgets/price_summary.dart';
import '../../../rewards/presentation/voucher_picker_screen.dart';
import '../../../rewards/domain/voucher_recommendation.dart';
import '../../data/cart_checkout_payload.dart';

class CartVoucherSummary extends StatefulWidget {
  final bool enabled;
  const CartVoucherSummary({super.key, this.enabled = true});
  @override
  State<CartVoucherSummary> createState() => _CartVoucherSummaryState();
}

class _CartVoucherSummaryState extends State<CartVoucherSummary> {
  final code = TextEditingController();
  String? selection, error, notice, quoteSignature;
  Json? quote;
  bool busy = false, choosing = false;
  bool get enabled => widget.enabled && !busy && !choosing;

  String signature(OrganicStore store) => jsonEncode({
    'session': store.api.sessionVersion,
    'cart': store.cart,
    'profile': store.profile,
    'promotion': store.selectedPromotionCode,
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selected = StoreScope.of(context).selectedVoucherCode;
    if (selected != selection) {
      selection = selected;
      code.text = selected;
      quote = null;
      error = notice = quoteSignature = null;
    }
  }

  void clear() {
    if (!enabled) return;
    setState(() {
      selection = '';
      code.clear();
      quote = null;
      error = notice = quoteSignature = null;
    });
    StoreScope.of(context).selectVoucher('');
  }

  Future<void> apply([String? chosen]) async {
    if (!enabled) return;
    final store = StoreScope.of(context);
    final value = (chosen ?? code.text).trim().toUpperCase();
    if (value.isEmpty) {
      clear();
      return;
    }
    if (value.length > 50) {
      setState(() => error = 'Mã voucher tối đa 50 ký tự.');
      return;
    }
    final snapshot = signature(store);
    final version = store.api.sessionVersion;
    setState(() {
      busy = true;
      error = notice = null;
      quote = null;
    });
    try {
      final body = store.loggedIn
          ? cartCheckoutPayload(store, voucher: value)
          : null;
      if (body == null && store.loggedIn) {
        final wallet = await store.rewardService.allWallet(
          isCurrent: () => mounted && version == store.api.sessionVersion,
        );
        final owned = wallet
            .where((v) => '${v['voucherCode']}'.toUpperCase() == value)
            .firstOrNull;
        if (owned == null ||
            !VoucherRecommendation.forCart(
              owned,
              store.cartItems,
              number(store.cart?['subtotal']),
            ).fitsCart) {
          throw const ApiException(
            'Voucher không phù hợp với giỏ hàng hiện tại.',
            400,
          );
        }
      }
      final checked = body == null ? null : await store.checkout.preview(body);
      if (!mounted || version != store.api.sessionVersion) return;
      if (snapshot != signature(store)) {
        setState(
          () => error = 'Giỏ hàng hoặc địa chỉ đã thay đổi. Vui lòng kiểm tra voucher lại.',
        );
        return;
      }
      setState(() {
        selection = value;
        code.text = value;
        quote = checked;
        quoteSignature = checked == null ? null : snapshot;
        notice = checked != null
            ? 'Đã áp dụng voucher $value.'
            : !store.loggedIn
            ? 'Đã chọn voucher $value. Mã được giữ khi đăng nhập và sẽ được kiểm tra ở bước đặt hàng.'
            : 'Đã chọn voucher $value. Bổ sung thông tin nhận hàng ở bước đặt hàng để kiểm tra mức giảm.';
      });
      store.selectVoucher(value);
    } catch (failure) {
      if (mounted && version == store.api.sessionVersion) {
        final unsuitable =
            failure is ApiException &&
            ([400, 404, 409, 422].contains(failure.status) ||
                failure.message.startsWith('Voucher chưa được áp dụng'));
        setState(
          () => error = unsuitable
              ? 'Voucher không phù hợp với giỏ hàng hiện tại.'
              : '$failure',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose() async {
    if (!enabled) return;
    setState(() => choosing = true);
    Json? chosen;
    try {
      if (await ensureLogin(context) && mounted) {
        chosen = await open<Json>(
          context,
          const VoucherPickerScreen(),
          account: true,
        );
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
    if (mounted && chosen != null) await apply('${chosen['voucherCode']}');
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final currentQuote = quoteSignature == signature(store) ? quote : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Voucher của bạn', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('cart.voucher.code'),
          controller: code,
          enabled: enabled,
          maxLength: 50,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã voucher',
            hintText: 'Nhập mã voucher',
            counterText: '',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
          onSubmitted: (_) => apply(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('cart.voucher.apply'),
              onPressed: enabled ? apply : null,
              child: Text(busy ? 'Đang kiểm tra…' : 'Áp dụng'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('cart.voucher.wallet'),
              onPressed: enabled ? choose : null,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('Chọn từ ví voucher'),
            ),
          ],
        ),
        if (store.selectedVoucherCode.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Đã chọn: ${store.selectedVoucherCode}',
                style: const TextStyle(color: moss),
              ),
              TextButton(
                key: const ValueKey('cart.voucher.remove'),
                onPressed: enabled ? clear : null,
                child: const Text('Bỏ voucher'),
              ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (notice != null && (quote == null || currentQuote != null))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(notice!, style: const TextStyle(color: moss)),
          ),
        if (store.selectedVoucherCode.isNotEmpty &&
                currentQuote == null &&
                notice == null ||
            quote != null && currentQuote == null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Mã đã chọn sẽ được kiểm tra lại theo giỏ hàng và thông tin nhận hàng hiện tại.',
            ),
          ),
        const SizedBox(height: 16),
        const Divider(),
        if (currentQuote != null)
          PriceSummary(currentQuote)
        else
          AmountRow('Tạm tính', store.cart?['subtotal'], total: true),
        const Text(
          'Giá, ưu đãi và phí giao hàng được xác nhận lại khi đặt hàng.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}
