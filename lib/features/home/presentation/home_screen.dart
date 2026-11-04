import 'package:flutter/material.dart';

import '../../store_info/presentation/store_info_screen.dart';

import 'package:organic_mobile/features/promotions/presentation/promotions_screen.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/product_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/widgets/product_grid.dart';
import 'package:organic_mobile/features/notifications/presentation/updates_screen.dart';
import 'package:organic_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/async_view.dart';
import 'package:organic_mobile/shared/widgets/brand.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback catalog;
  const HomeScreen({super.key, required this.catalog});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AsyncView<bool>(
      load: () async {
        await store.loadHome();
        return true;
      },
      builder: (_) => RefreshIndicator(
        onRefresh: store.loadHome,
        child: ListView(
          children: [
            Container(
              color: ink,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
              child: const Text(
                'MỘT CHÚT XANH, MỘT ĐỜI LÀNH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: surface,
                  fontSize: 9,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
              child: Row(
                children: [
                  const Brand(),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Tìm sản phẩm',
                    onPressed: widget.catalog,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () => open(context, const UpdatesScreen()),
                    icon: Badge(
                      isLabelVisible: store.unread > 0,
                      label: Text('${store.unread}'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const Text(
                    'TỪ NÔNG TRẠI ĐẾN BÀN ĂN',
                    style: TextStyle(
                      color: moss,
                      letterSpacing: 1.9,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Lành từ đất.\nTốt cho bạn.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Những lựa chọn tươi lành mỗi ngày.\nKhám phá thực phẩm và câu chuyện nguồn gốc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.8, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: widget.catalog,
                    label: const Text('Khám phá sản phẩm'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                  const SizedBox(height: 26),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/hero.jpg',
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _Trust(Icons.grass, 'Nguồn gốc rõ ràng')),
                      Expanded(
                        child: _Trust(
                          Icons.verified_outlined,
                          'Hồ sơ chứng nhận',
                        ),
                      ),
                      Expanded(
                        child: _Trust(
                          Icons.local_shipping_outlined,
                          'Theo dõi đơn hàng',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Heading(
              'Tươi lành mỗi ngày',
              eyebrow: 'Ghé vườn nhà organicfood',
              trailing: TextButton(
                onPressed: widget.catalog,
                child: const Text('Xem hết →', style: TextStyle(fontSize: 11)),
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                separatorBuilder: (_, i) => const SizedBox(width: 12),
                itemCount: objects(store.home['categories']).length,
                itemBuilder: (_, index) {
                  final c = objects(store.home['categories'])[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => open(
                      context,
                      CatalogScreen(
                        categoryId: '${c['id']}',
                        title: '${c['name']}',
                      ),
                    ),
                    child: Container(
                      width: 125,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: index.isEven ? sage : const Color(0xFFF4E8DC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            [
                              Icons.eco_outlined,
                              Icons.spa_outlined,
                              Icons.grain,
                              Icons.local_florist_outlined,
                            ][index % 4],
                            color: moss,
                            size: 24,
                          ),
                          const Spacer(),
                          Text(
                            '${c['name']}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${c['productCount']} sản phẩm',
                            style: const TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Heading(
              'organicfood chọn cho bạn',
              eyebrow: 'Sản phẩm nổi bật',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: OutlinedButton.icon(
                onPressed: () => open(context, const PromotionsScreen()),
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(
                  'Ưu đãi & combo${store.publicOffers.isEmpty ? '' : ' (${store.publicOffers.length})'}',
                ),
              ),
            ),
            ProductGrid(
              store.featured,
              onTap: (p) => open(context, ProductScreen(p.id)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Panel(
                color: sage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.loyalty_outlined, color: moss, size: 30),
                    const SizedBox(height: 12),
                    Text(
                      'Mua lành, tích thêm xanh.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Theo dõi điểm tích lũy và dùng điểm cho những lần mua tiếp theo.',
                      style: TextStyle(color: muted),
                    ),
                    TextButton(
                      onPressed: () => open(context, const RewardsScreen()),
                      child: const Text('Khám phá organicfood thành viên →'),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Text(
                'organicfood  ·  Một chút xanh, một đời lành.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontFamily: 'Lora'),
              ),
            ),
            TextButton(
              onPressed: () => open(context, const StoreInfoScreen()),
              child: const Text('Thông tin & liên hệ organicfood'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Trust(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: moss, size: 21),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(fontSize: 8, color: muted)),
    ],
  );
}
