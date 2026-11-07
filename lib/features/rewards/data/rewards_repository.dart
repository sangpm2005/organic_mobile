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
  Future<List<Json>> allWallet({required bool Function() isCurrent}) async {
    final rows = <Json>[], seen = <String>{};
    for (var page = 0; isCurrent(); page++) {
      final data = await wallet(page);
      if (!isCurrent()) return [];
      final items = pageItems(data);
      var added = 0;
      for (final item in items) {
        final key = '${item['id'] ?? item['voucherCode']}';
        if (seen.add(key)) {
          rows.add(item);
          added++;
        }
      }
      final total = data['totalElements'];
      if (added == 0 ||
          data['last'] == true ||
          data['hasNext'] == false ||
          (total != null
              ? (page * 20 + items.length) >= number(total)
              : items.length < 20)) {
        break;
      }
    }
    return rows;
  }

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
