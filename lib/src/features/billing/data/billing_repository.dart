import '../../../core/network/api_client.dart';
import '../models/subscription_info.dart';

class BillingRepository {
  BillingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SubscriptionInfo> fetchSubscription() async {
    final json = await _apiClient.getJson(
      '/billing/subscription',
      authenticated: true,
    );
    if (json is! Map<String, dynamic>) {
      return SubscriptionInfo.freeDefaults();
    }
    return SubscriptionInfo.fromJson(json);
  }

  Future<String> createCheckoutUrl() async {
    final json = await _apiClient.postJson(
      '/billing/checkout',
      authenticated: true,
    );
    final url = json['checkout_url'];
    if (url is! String || url.isEmpty) {
      throw const ApiException('Checkout URL missing from server.');
    }
    return url;
  }

  Future<void> revokeOtherDevices() async {
    await _apiClient.postJson(
      '/billing/devices/revoke-others',
      authenticated: true,
    );
  }
}
