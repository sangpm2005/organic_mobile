import 'package:flutter/material.dart';
import 'package:organic_mobile/features/account/presentation/addresses_screen.dart';
import 'package:organic_mobile/features/account/presentation/profile_screen.dart';
import 'package:organic_mobile/features/auth/presentation/widgets/login_gate.dart';
import 'package:organic_mobile/features/notifications/presentation/updates_screen.dart';
import 'package:organic_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/account_error.dart';
import 'package:organic_mobile/shared/widgets/brand.dart';
import 'package:organic_mobile/shared/widgets/heading.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

import '../../store_info/presentation/store_info_screen.dart';

import '../../feedback/presentation/feedback_list_screen.dart';
import '../../returns/presentation/returns_screen.dart';
import '../../reviews/presentation/reviews_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loggedIn) {
      return const LoginGate(
        'Một tài khoản, cùng giỏ hàng và điểm thưởng trên web lẫn app.',
      );
    }
    return RefreshIndicator(
      onRefresh: store.refreshAccount,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Heading('Góc nhỏ của bạn', eyebrow: 'Thành viên organicfood'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Panel(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: sage,
                    foregroundImage:
                        '${store.profile?['avatarUrl'] ?? ''}'.isEmpty
                        ? null
                        : NetworkImage('${store.profile!['avatarUrl']}'),
                    onForegroundImageError:
                        '${store.profile?['avatarUrl'] ?? ''}'.isEmpty
                        ? null
                        : (_, _) {},
                    child: const Icon(
                      Icons.person_outline,
                      size: 30,
                      color: moss,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${store.profile?['fullName'] ?? store.user?['fullName'] ?? ''}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${store.profile?['email'] ?? store.user?['email'] ?? ''}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (store.accountError != null) AccountError(store),
          ListTile(
            leading: const Icon(Icons.favorite_outline, color: moss),
            title: const Text('Sản phẩm yêu thích'),
            subtitle: Text(
              '${store.favorites.length} sản phẩm đã lưu trên ứng dụng',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const FavoritesScreen(), account: true),
          ),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined, color: moss),
            title: const Text('Đánh giá của tôi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const ReviewsScreen(), account: true),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: moss),
            title: const Text('Phản hồi & hỗ trợ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                open(context, const FeedbackListScreen(), account: true),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_return_outlined, color: moss),
            title: const Text('Đổi trả & hoàn tiền'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const ReturnsScreen(), account: true),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.loyalty_outlined, color: moss),
            title: const Text('Điểm xanh & ưu đãi'),
            subtitle: Text('${store.rewards?['available'] ?? 0} điểm khả dụng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const RewardsScreen()),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.person_outline, color: moss),
            title: const Text('Thông tin cá nhân'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const ProfileScreen(), account: true),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.location_on_outlined, color: moss),
            title: const Text('Địa chỉ nhận hàng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const AddressesScreen(), account: true),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.notifications_none, color: moss),
            title: const Text('Cập nhật đơn hàng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, const UpdatesScreen()),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Divider(),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.support_agent_outlined, color: moss),
            title: const Text('Thông tin & liên hệ cửa hàng'),
            subtitle: const Text('Địa chỉ, giờ mở cửa và câu hỏi thường gặp'),
            onTap: () => open(context, const StoreInfoScreen()),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.logout, color: moss),
            title: const Text('Đăng xuất'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất khỏi organicfood?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Ở lại'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await store.logout();
              }
            },
          ),
          const SizedBox(height: 20),
          const Center(child: Brand()),
          const SizedBox(height: 12),
          const Text(
            'organicfood · Phiên bản 0.1.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
