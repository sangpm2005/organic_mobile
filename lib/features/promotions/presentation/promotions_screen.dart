import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/async_view.dart';
import '../../rewards/presentation/widgets/voucher_card.dart';
import 'widgets/promotion_products.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ưu đãi từ Mộc')),
      body: AsyncView<List<Json>>(
        load: store.promotionService.feed,
        builder: (offers) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (offers.isEmpty) const Text('Chưa có ưu đãi đang hiệu lực.'),
            for (final offer in offers)
              VoucherCard(
                offer,
                action: PromotionProducts(
                  key: ValueKey('${offer['id']}:${store.api.sessionVersion}'),
                  offer: offer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
