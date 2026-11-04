import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

class NotificationsRepository {
  final OrganicApi api;
  NotificationsRepository(this.api);
  Future<Json> page(int page) async => object(
    await api.request('GET', '/inbox', query: {'page': page, 'size': 20}),
  );
  Future<void> read(String id) async =>
      api.request('PATCH', '/inbox/${Uri.encodeComponent(id)}/read');
}
