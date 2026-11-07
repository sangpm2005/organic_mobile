import 'package:flutter/material.dart';

import '../../../shared/navigation/navigation.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/widgets/panel.dart';

class PushSettings extends StatelessWidget {
  const PushSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final push = StoreScope.of(context).push;
    return ListenableBuilder(
      listenable: push,
      builder: (context, _) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông báo trên điện thoại',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              push.enabled
                  ? 'Đang nhận cập nhật đơn hàng và hỗ trợ trên thiết bị này.'
                  : 'Bật để nhận cập nhật khi bạn không mở ứng dụng.',
            ),
            if (push.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  push.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: push.busy
                  ? null
                  : () async {
                      try {
                        if (push.enabled) {
                          await push.disable();
                        } else {
                          await push.enable();
                        }
                      } catch (e) {
                        if (context.mounted) toast(context, e);
                      }
                    },
              icon: Icon(
                push.enabled
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
              ),
              label: Text(
                push.busy
                    ? 'Đang cập nhật…'
                    : push.enabled
                    ? 'Tắt trên thiết bị này'
                    : 'Bật thông báo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
