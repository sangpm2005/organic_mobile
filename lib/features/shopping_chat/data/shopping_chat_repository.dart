import '../../../core/network/organic_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

class ShoppingChatRepository {
  final OrganicApi api;
  ShoppingChatRepository(this.api);
  Future<Json> ask(
    String message,
    List<Json> history, {
    required bool authenticated,
  }) async {
    if (message.trim().isEmpty || message.trim().length > 1200) {
      throw const ApiException('Nhập câu hỏi tối đa 1.200 ký tự.');
    }
    final version = api.sessionVersion;
    final reply = object(
      await api.request(
        'POST',
        '/shopping-chat',
        authenticated: authenticated,
        timeout: const Duration(seconds: 60),
        body: {
          'message': message.trim(),
          'history': history
              .where(
                (t) =>
                    ['user', 'assistant'].contains(t['role']) &&
                    '${t['text'] ?? ''}'.trim().isNotEmpty,
              )
              .toList()
              .reversed
              .take(8)
              .toList()
              .reversed
              .map(
                (t) => {
                  'role': t['role'],
                  'text': '${t['text']}'.substring(
                    0,
                    '${t['text']}'.length.clamp(0, 2000),
                  ),
                },
              )
              .toList(),
        },
      ),
    );
    if (version != api.sessionVersion) {
      throw const ApiException(
        'Phiên đăng nhập đã thay đổi. Hãy gửi lại câu hỏi.',
      );
    }
    return reply;
  }
}
