import 'package:flutter/material.dart';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/state/store_scope.dart';
import '../../../shared/navigation/navigation.dart';
import '../../../shared/widgets/panel.dart';
import '../../catalog/presentation/product_screen.dart';
import '../../orders/presentation/order_screen.dart';
import '../../orders/domain/order_labels.dart';
import '../data/shopping_chat_repository.dart';

class ShoppingChatScreen extends StatefulWidget {
  const ShoppingChatScreen({super.key});
  @override
  State<ShoppingChatScreen> createState() => _ShoppingChatScreenState();
}

class _ShoppingChatScreenState extends State<ShoppingChatScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final turns = <Json>[];
  bool busy = false;
  String? error;
  int? session;
  int request = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = StoreScope.of(context).api.sessionVersion;
    if (session != version) {
      session = version;
      request++;
      turns.clear();
      busy = false;
      error = null;
      input.clear();
    }
  }

  void toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> send() async {
    if (busy || input.text.trim().isEmpty) return;
    final store = StoreScope.of(context), message = input.text.trim();
    final version = ++request;
    final history = turns
        .map((t) => {'role': t['role'], 'text': t['text']})
        .toList();
    setState(() {
      busy = true;
      error = null;
      turns.add({'role': 'user', 'text': message});
      input.clear();
    });
    toBottom();
    try {
      final result = await ShoppingChatRepository(store.api)
          .ask(message, history, authenticated: store.loggedIn);
      if (!mounted ||
          version != request ||
          session != store.api.sessionVersion) {
        return;
      }
      setState(
        () => turns.add({
          ...result,
          'role': 'assistant',
          'text': result['answer'] ?? 'Bạn thử hỏi cụ thể hơn nhé.',
        }),
      );
      toBottom();
    } catch (e) {
      if (mounted && version == request) {
        setState(() {
          error = '$e';
          turns.removeLast();
          input.text = message;
        });
      }
    } finally {
      if (mounted && version == request) setState(() => busy = false);
    }
  }

  Future<void> product(Json p) async {
    final api = StoreScope.of(context).api;
    try {
      final result = object(
        await api.request(
          'GET',
          '/products/slug/${Uri.encodeComponent('${p['slug']}')}',
          authenticated: false,
        ),
      );
      if (mounted && result['id'] != null) {
        await open(context, ProductScreen('${result['id']}'));
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  void dispose() {
    request++;
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trợ lý Organic Food')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Mình có thể gợi ý sản phẩm, xem giá và hỗ trợ tra cứu đơn của bạn.',
                ),
                if (turns.isEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final text in [
                        'Sản phẩm nào rẻ nhất?',
                        'Gợi ý rau củ còn hàng',
                        'Đơn hàng của tôi',
                      ])
                        ActionChip(
                          label: Text(text),
                          onPressed: () {
                            input.text = text;
                            send();
                          },
                        ),
                    ],
                  ),
                for (final turn in turns)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            turn['role'] == 'user' ? 'Bạn' : 'Organic Food',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SelectableText('${turn['text']}'),
                          for (final p in objects(turn['products']))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${p['name']}'),
                              subtitle: Text(
                                '${p['variant']} · ${money(p['price'])} · Còn ${p['available'] ?? 'đang cập nhật'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => product(p),
                            ),
                          for (final order in objects(turn['orders']))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${order['code']}'),
                              subtitle: Text(orderStatus(order['status'])),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => open(
                                context,
                                OrderScreen('${order['id']}'),
                                account: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Trợ lý đang trả lời…'),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    maxLength: 1200,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Bạn muốn tìm gì hôm nay?',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Gửi câu hỏi',
                  onPressed: busy ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
