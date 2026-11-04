import '../../../core/network/organic_api.dart';
import '../../../core/utils/json.dart';

class PromotionsRepository {
  final OrganicApi api;
  PromotionsRepository(this.api);
  Future<List<Json>> feed() async => objects(
    object(
      await api.request('GET', '/home/promotions', authenticated: false),
    )['offers'],
  );
}
