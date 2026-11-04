import '../../../core/network/organic_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/media/upload_file.dart';
import '../../../core/utils/json.dart';
import '../../../shared/media/media_validation.dart';

class ReturnsRepository {
  final OrganicApi api;
  ReturnsRepository(this.api);
  Future<Json> eligible(String orderId) async => object(
    await api.request(
      'GET',
      '/return-requests/eligible-items',
      query: {'orderId': orderId},
    ),
  );
  Future<Json> list(int page, {String? orderId, String? status}) async =>
      object(
        await api.request(
          'GET',
          '/return-requests/me',
          query: {
            'page': page,
            'size': 20,
            'orderId': orderId,
            'status': status,
          },
        ),
      );
  Future<Json> detail(String id) async => object(
    await api.request('GET', '/return-requests/${Uri.encodeComponent(id)}'),
  );
  Future<Json> histories(String id, int page) async => object(
    await api.request(
      'GET',
      '/return-requests/${Uri.encodeComponent(id)}/histories',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<Json> progress(String id) async => object(
    await api.request(
      'GET',
      '/return-requests/${Uri.encodeComponent(id)}/warehouse-progress',
    ),
  );
  Future<Json> receipts(String id, int page) async => object(
    await api.request(
      'GET',
      '/return-requests/${Uri.encodeComponent(id)}/receipts',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<Json> execution(String id) async => object(
    await api.request(
      'GET',
      '/return-requests/${Uri.encodeComponent(id)}/execution',
    ),
  );
  Future<Json> create(Json payload, List<UploadFile> files, String key) async {
    validateMedia(files, imagesOnly: true, required: true);
    return object(
      await api.request(
        'POST',
        '/return-requests',
        body: payload,
        files: files,
        fileField: 'images',
        jsonPart: 'request',
        idempotencyKey: key,
        timeout: const Duration(seconds: 180),
      ),
    );
  }

  Future<Json> action(
    String id,
    String action,
    String note, {
    int? proposalVersion,
  }) async {
    if (![
      'cancel',
      'accept',
      'decline',
      'submit-information',
    ].contains(action)) {
      throw const ApiException('Thao tác đổi trả không hợp lệ.');
    }
    if (['accept', 'decline'].contains(action) &&
        (proposalVersion == null || proposalVersion < 1)) {
      throw const ApiException('Phương án đã thay đổi. Vui lòng tải lại.');
    }
    return object(
      await api.request(
        'POST',
        '/return-requests/${Uri.encodeComponent(id)}/$action',
        body: {
          'note': note,
          if (['accept', 'decline'].contains(action))
            'proposalVersion': proposalVersion,
        },
      ),
    );
  }
}
