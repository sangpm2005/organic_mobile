import '../../../core/network/organic_api.dart';
import '../../../core/media/upload_file.dart';
import '../../../core/utils/json.dart';
import '../../../shared/media/media_validation.dart';

class FeedbackRepository {
  final OrganicApi api;
  FeedbackRepository(this.api);
  Future<Json> list(
    int page, {
    String? orderId,
    String? status,
    String search = '',
  }) async => object(
    await api.request(
      'GET',
      '/feedbacks/me',
      query: {
        'page': page,
        'size': 20,
        'orderId': orderId,
        'status': status,
        'search': search,
      },
    ),
  );
  Future<Json> detail(String id) async =>
      object(await api.request('GET', '/feedbacks/${Uri.encodeComponent(id)}'));
  Future<Json> messages(String id, int page) async => object(
    await api.request(
      'GET',
      '/feedbacks/${Uri.encodeComponent(id)}/messages',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<Json> create(Json body) async =>
      object(await api.request('POST', '/feedbacks', body: body));
  Future<Json> reply(String id, String content) async => object(
    await api.request(
      'POST',
      '/feedbacks/${Uri.encodeComponent(id)}/messages',
      body: {'content': content},
    ),
  );
  Future<Json> upload(String id, UploadFile file, {String? messageId}) async {
    validateMedia([file]);
    return object(
      await api.request(
        'POST',
        '/feedbacks/${Uri.encodeComponent(id)}/media',
        body: {'messageId': messageId},
        files: [file],
        fileField: 'file',
        timeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<void> deleteMedia(String id, String mediaId) => api.request(
    'DELETE',
    '/feedbacks/${Uri.encodeComponent(id)}/media/${Uri.encodeComponent(mediaId)}',
  );
  Future<Json> close(
    String id,
    String note, {
    bool reopen = false,
  }) async => object(
    await api.request(
      'POST',
      '/feedbacks/${Uri.encodeComponent(id)}/${reopen ? 'reopen' : 'close'}',
      body: {'note': note},
    ),
  );
}
