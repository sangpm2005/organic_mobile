import 'package:flutter/material.dart';
import 'package:organic_mobile/features/account/presentation/account_screen.dart';
import 'package:organic_mobile/features/cart/presentation/cart_screen.dart';
import 'package:organic_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:organic_mobile/features/home/presentation/home_screen.dart';
import 'package:organic_mobile/features/orders/presentation/orders_screen.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';

class ShopShell extends StatefulWidget {
  const ShopShell({super.key});
  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> with WidgetsBindingObserver {
  int selected = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      StoreScope.of(context).setActive(state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: IndexedStack(
              index: selected,
              children: [
                HomeScreen(catalog: () => setState(() => selected = 1)),
                const CatalogScreen(embedded: true),
                const CartScreen(),
                const OrdersScreen(),
                const AccountScreen(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          setState(() => selected = i);
          if (i >= 2 && store.loggedIn) {
            store.refreshAccount();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Sản phẩm',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: store.cartCount > 0,
              label: Text('${store.cartCount}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            label: 'Giỏ hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
