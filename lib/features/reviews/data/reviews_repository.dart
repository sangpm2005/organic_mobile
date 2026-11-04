import '../../../core/network/organic_api.dart';
import '../../../core/media/upload_file.dart';
import '../../../core/utils/json.dart';
import '../../../shared/media/media_validation.dart';

class ReviewsRepository {
  final OrganicApi api;
  ReviewsRepository(this.api);
  Future<Json> published(
    String productId,
    int page, {
    int? rating,
    String sort = 'newest',
  }) async => object(
    await api.request(
      'GET',
      '/products/${Uri.encodeComponent(productId)}/reviews',
      authenticated: false,
      query: {'page': page, 'size': 6, 'rating': rating, 'sort': sort},
    ),
  );
  Future<Json> mine(int page) async => object(
    await api.request('GET', '/reviews/me', query: {'page': page, 'size': 20}),
  );
  Future<Json> eligible(int page, {String? productId}) async => object(
    await api.request(
      'GET',
      '/reviews/eligible-items',
      query: {'page': page, 'size': 20, 'productId': productId},
    ),
  );
  Future<Json> get(String id) async =>
      object(await api.request('GET', '/reviews/${Uri.encodeComponent(id)}'));
  Future<void> remove(String id) async =>
      api.request('DELETE', '/reviews/${Uri.encodeComponent(id)}');
  Future<Json> submit(Json body, List<UploadFile> files) async {
    validateMedia(files);
    return object(
      await api.request(
        'POST',
        '/reviews/submission',
        body: body,
        files: files,
        jsonPart: 'review',
        fileField: 'files',
        timeout: const Duration(seconds: 180),
      ),
    );
  }
}
