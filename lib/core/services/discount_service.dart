import 'package:customer_order_app/core/models/discount_model.dart';

import '../config/api_config.dart';
import '../interfaces/discount_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class DiscountService implements DiscountServiceInterface {
  final HttpClientInterface _client;
  final String _baseUrl;

  DiscountService({
    required HttpClientInterface client,
    String? baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl ?? ApiConfig.inventoryUrl;

  Future<Map<String, String>> _getHeaders() async {
    final tokenService = serviceLocator<TokenServiceInterface>();
    final tokens = await tokenService.getStoredTokens();

    if (tokens == null || tokens.userAccessToken.isEmpty) {
      throw Exception('No authentication token available');
    }

    return {
      ...ApiConfig.getDefaultHeaders(),
      'Authorization': 'Bearer ${tokens.userAccessToken}',
    };
  }

  @override
  Future<List<DiscountModel>> fetchDiscounts() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        '$_baseUrl/discount/option/delivery',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = (response.data)['data'] as List;
        return data.map((discount) => DiscountModel.fromJson(discount)).toList();
      }
      throw Exception('Failed to load discounts');
    } catch (e) {
      print('Error fetching discounts: $e');
      rethrow;
    }
  }
}
