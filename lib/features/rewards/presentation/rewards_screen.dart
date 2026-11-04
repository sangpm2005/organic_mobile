import 'package:flutter/material.dart';

import '../../../app/state/organic_store.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/widgets/login_gate.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/panel.dart';
import '../../../shared/widgets/paged_records.dart';
import 'widgets/voucher_card.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool busy = false;
  int revision = 0;
  Future<void> exchange(OrganicStore store, [Json? offer]) async {
    if (offer != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đổi điểm lấy voucher?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sử dụng ${offer['pointsCost']} điểm. Voucher có hiệu lực ${offer['voucherValidDays']} ngày kể từ khi đổi.',
                ),
                VoucherCard(offer),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận đổi'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final voucher = await store.exchangeVoucher(offer);
      if (mounted) {
        setState(() => revision++);
        toast(
          context,
          'Đã nhận voucher ${voucher['voucherCode']}. Xem ở Ví voucher.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scope = '${store.api.sessionVersion}:$revision';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thành viên organicfood'),
          bottom: store.loggedIn
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Điểm'),
                    Tab(text: 'Đổi voucher'),
                    Tab(text: 'Ví voucher'),
                  ],
                )
              : null,
        ),
        body: !store.loggedIn
            ? const LoginGate(
                'Tích điểm từ đơn hoàn tất và đổi ưu đãi dành cho bạn.',
              )
            : Column(
                children: [
                  if (store.pendingVoucherExchange != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Lần đổi voucher trước chưa rõ kết quả. Kiểm tra lại trước khi đổi tiếp.',
                          ),
                          TextButton(
                            onPressed: busy ? null : () => exchange(store),
                            child: const Text('Kiểm tra lần đổi đang chờ'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        PagedRecords(
                          key: ValueKey('history:$scope'),
                          empty: 'Chưa có giao dịch điểm.',
                          header: [
                            Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${store.rewards?['available'] ?? '—'} điểm khả dụng',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(
                                    'Đang giữ: ${store.rewards?['reserved'] ?? 0} điểm',
                                  ),
                                  Text(
                                    'Mỗi ${money(store.rewards?['earnPerVnd'] ?? 100000)} của đơn hoàn tất tích 1 điểm. 1 điểm đổi ${money(store.rewards?['redeemValue'] ?? 2000)}; tối đa ${store.rewards?['redeemLimit'] ?? 50} điểm/đơn.',
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await store.refreshAccount(force: true);
                                      if (mounted) setState(() => revision++);
                                    },
                                    child: const Text('Cập nhật số dư'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          load: (page) async {
                            final rows = await store.rewardService.history(
                              page,
                            );
                            return {
                              'items': rows,
                              'totalElements':
                                  page * 20 +
                                  rows.length +
                                  (rows.length == 20 ? 1 : 0),
                            };
                          },
                          itemBuilder: (t) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${t['note'] ?? const {'voucher_exchange': 'Đổi voucher', 'earn': 'Tích điểm', 'redeem': 'Trừ điểm', 'reserve': 'Giữ điểm', 'release': 'Hoàn điểm', 'return_restore': 'Hoàn điểm đổi trả', 'return_reverse': 'Điều chỉnh điểm'}[t['type']] ?? t['type']}',
                            ),
                            subtitle: Text(dateText(t['createdAt'])),
                            trailing: Text(
                              '${number(t['pointsDelta']) > 0 ? '+' : ''}${t['pointsDelta']}',
                            ),
                          ),
                        ),
                        PagedRecords(
                          key: ValueKey('offers:$scope'),
                          load: store.rewardService.offers,
                          empty: 'Chưa có ưu đãi đổi điểm.',
                          itemBuilder: (p) => VoucherCard(
                            p,
                            action: FilledButton(
                              onPressed:
                                  busy ||
                                      store.pendingVoucherExchange != null ||
                                      store.rewards == null ||
                                      number(store.rewards?['available']) <
                                          number(p['pointsCost'])
                                  ? null
                                  : () => exchange(store, p),
                              child: Text('Đổi ${p['pointsCost']} điểm'),
                            ),
                          ),
                        ),
                        PagedRecords(
                          key: ValueKey('wallet:$scope'),
                          load: store.rewardService.wallet,
                          empty: 'Bạn chưa có voucher.',
                          itemBuilder: (p) => VoucherCard(
                            p,
                            action: p['usable'] != true
                                ? null
                                : TextButton(
                                    onPressed: () {
                                      store.selectVoucher(
                                        '${p['voucherCode']}',
                                      );
                                      open(
                                        context,
                                        Scaffold(
                                          appBar: AppBar(
                                            title: const Text('Giỏ hàng'),
                                          ),
                                          body: const CartScreen(),
                                        ),
                                        account: true,
                                      );
                                    },
                                    child: const Text('Dùng cho giỏ hàng'),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
