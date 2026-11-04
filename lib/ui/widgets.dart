import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import 'theme.dart';

class StoreScope extends InheritedNotifier<OrganicStore> {
  const StoreScope({
    super.key,
    required OrganicStore store,
    required super.child,
  }) : super(notifier: store);
  static OrganicStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

void toast(BuildContext context, Object message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$message'), behavior: SnackBarBehavior.floating),
  );
}

Future<T?> open<T>(BuildContext context, Widget page, {bool account = false}) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => account ? SessionBoundary(child: page) : page,
      ),
    );

class SessionBoundary extends StatefulWidget {
  final Widget child;
  const SessionBoundary({super.key, required this.child});
  @override
  State<SessionBoundary> createState() => _SessionBoundaryState();
}

class _SessionBoundaryState extends State<SessionBoundary> {
  int? version;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    version ??= store.api.sessionVersion;
    if (store.loggedIn && version == store.api.sessionVersion) {
      return widget.child;
    }
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        'Phiên đăng nhập đã thay đổi',
        'Vui lòng trở về trang chính và mở lại chức năng này.',
        action: FilledButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Về trang chính'),
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.spa_outlined, color: moss, size: 30),
      SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'mộc.',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Text(
            'ORGANIC LIVING',
            style: TextStyle(fontSize: 7, letterSpacing: 2.4, color: moss),
          ),
        ],
      ),
    ],
  );
}

class Heading extends StatelessWidget {
  final String title, eyebrow;
  final Widget? trailing;
  const Heading(this.title, {super.key, this.eyebrow = '', this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: moss,
                    fontSize: 9,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.color = surface,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.eco_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: sage,
          child: Icon(icon, size: 36, color: moss),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.7),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T) builder;
  const AsyncView({super.key, required this.load, required this.builder});
  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return EmptyState(
          'Chưa tải được dữ liệu',
          '${snapshot.error}',
          icon: Icons.cloud_off_outlined,
          action: OutlinedButton.icon(
            onPressed: () => setState(() => future = widget.load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(60),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

class ProductPhoto extends StatelessWidget {
  final String url;
  final double? height;
  const ProductPhoto(this.url, {super.key, this.height});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: sage,
    child: url.isEmpty
        ? SizedBox(
            height: height,
            child: const Center(
              child: Icon(Icons.eco_outlined, size: 45, color: moss),
            ),
          )
        : Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => SizedBox(
              height: height,
              child: const Center(
                child: Icon(Icons.eco_outlined, size: 45, color: moss),
              ),
            ),
          ),
  );
}

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductTile(this.product, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ProductPhoto(product.image),
                  ),
                  if (product.verified)
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✓ Hữu cơ',
                          style: TextStyle(fontSize: 9, color: moss),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 12, 5, 0),
              child: Text(
                product.category.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  color: muted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                product.variantName ?? 'Xem quy cách',
                maxLines: 1,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.comparePrice > product.price)
                        Text(
                          money(product.comparePrice),
                          style: const TextStyle(
                            fontSize: 9,
                            color: muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        money(product.price),
                        style: const TextStyle(
                          fontSize: 15,
                          color: moss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: sage,
                  child: Icon(Icons.arrow_forward, color: moss, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    ),
  );
}

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onTap;
  const ProductGrid(this.products, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.maxWidth > 650 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: 290,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => ProductTile(
          products[i],
          key: ValueKey('product.tile.${products[i].id}'),
          onTap: () => onTap(products[i]),
        ),
      );
    },
  );
}

class AmountRow extends StatelessWidget {
  final String label;
  final dynamic amount;
  final bool total;
  const AmountRow(this.label, this.amount, {super.key, this.total = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total ? ink : muted,
              fontWeight: total ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          money(amount),
          style: TextStyle(
            fontSize: total ? 20 : 13,
            fontWeight: total ? FontWeight.w600 : FontWeight.normal,
            color: total ? moss : ink,
          ),
        ),
      ],
    ),
  );
}
