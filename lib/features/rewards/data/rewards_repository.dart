import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

class RewardsRepository {
  final OrganicApi api;
  RewardsRepository(this.api);
  Future<Json> offers(int page) async => object(
    await api.request(
      'GET',
      '/customers/me/voucher-offers',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<Json> wallet(int page) async => object(
    await api.request(
      'GET',
      '/customers/me/vouchers',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<List<Json>> history(int page) async => objects(
    await api.request(
      'GET',
      '/customers/me/reward-transactions',
      query: {'page': page, 'size': 20},
    ),
  );
  Future<Json> exchange(Json payload, String key) async => object(
    await api.request(
      'POST',
      '/customers/me/vouchers/exchange',
      body: payload,
      idempotencyKey: key,
    ),
  );
}
