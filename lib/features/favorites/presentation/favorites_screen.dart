import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/paged_records.dart';
import '../../catalog/presentation/product_screen.dart';
import '../../catalog/presentation/widgets/product_photo.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        ids = store.favorites.toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm yêu thích')),
      body: PagedRecords(
        key: ValueKey('${store.api.sessionVersion}:${ids.join(',')}'),
        empty: 'Chưa lưu sản phẩm. Chạm biểu tượng trái tim trong chi tiết sản phẩm để lưu lại.',
        load: (page) async {
          final rows = await Future.wait(
            ids.skip(page * 20).take(20).map((id) async {
              try {
                return {
                  ...object(
                    await store.api.request(
                      'GET',
                      '/products/${Uri.encodeComponent(id)}',
                      authenticated: false,
                    ),
                  ),
                  'id': id,
                };
              } on ApiException catch (e) {
                if (e.status == 404) {
                  return <String, dynamic>{
                    'id': id,
                    'productName': 'Sản phẩm không còn hiển thị',
                    'unavailable': true,
                  };
                }
                rethrow;
              }
            }),
          );
          return {'items': rows, 'totalElements': ids.length};
        },
        itemBuilder: (p) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 55,
            height: 55,
            child: ProductPhoto(
              '${objects(p['images']).firstOrNull?['imageUrl'] ?? p['imageUrl'] ?? ''}',
            ),
          ),
          title: Text('${p['productName']}'),
          subtitle: Text('${p['productCode'] ?? ''}'),
          onTap: p['unavailable'] == true
              ? null
              : () => open(context, ProductScreen('${p['id']}')),
          trailing: IconButton(
            onPressed: () async {
              try {
                await store.toggleFavorite('${p['id']}');
              } catch (e) {
                if (context.mounted) toast(context, e);
              }
            },
            icon: const Icon(Icons.favorite),
            tooltip: 'Bỏ yêu thích',
          ),
        ),
      ),
    );
  }
}
