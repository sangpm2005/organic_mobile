import 'package:flutter/material.dart';
import 'package:organic_mobile/core/utils/json.dart';
import 'package:organic_mobile/features/account/presentation/address_form.dart';
import 'package:organic_mobile/features/address/domain/vietnam_address.dart';
import 'package:organic_mobile/shared/navigation/navigation.dart';
import 'package:organic_mobile/shared/state/store_scope.dart';
import 'package:organic_mobile/shared/theme/organic_theme.dart';
import 'package:organic_mobile/shared/widgets/account_error.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';
import 'package:organic_mobile/shared/widgets/panel.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        addresses = objects(StoreScope.of(context).profile?['addresses']);
    return Scaffold(
      appBar: AppBar(title: const Text('Địa chỉ nhận hàng')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          ...addresses.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['label'] ?? 'Địa chỉ'}${a['isDefault'] == true ? ' · Mặc định' : ''}',
                      style: const TextStyle(
                        color: moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${a['receiverName']} · ${a['receiverPhone']}'),
                    Text(
                      savedAddressText(a),
                      style: const TextStyle(color: muted),
                    ),
                    TextButton(
                      onPressed: () =>
                          open(context, AddressForm(address: a), account: true),
                      child: const Text('Chỉnh sửa'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Xóa địa chỉ này?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Giữ lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Xóa'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true) return;
                        try {
                          await store.api.request(
                            'DELETE',
                            '/customers/me/addresses/${Uri.encodeComponent('${a['id']}')}',
                          );
                          await store.refreshAccount(force: true);
                        } catch (e) {
                          if (context.mounted) toast(context, e);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa địa chỉ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (addresses.isEmpty)
            const EmptyState(
              'Chưa có địa chỉ',
              'Lưu địa chỉ để đặt hàng nhanh hơn.',
              icon: Icons.location_on_outlined,
            ),
          FilledButton.icon(
            onPressed: () => open(context, const AddressForm(), account: true),
            icon: const Icon(Icons.add),
            label: const Text('Thêm địa chỉ'),
          ),
          if (store.accountError != null) AccountError(store),
        ],
      ),
    );
  }
}
