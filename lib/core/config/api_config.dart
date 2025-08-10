import '../../environment.dart';

class ApiConfig {
  static const String baseUrl = Environment.inventoryUrl;
  static const String inventoryUrl = Environment.inventoryUrl;
  static const String authMobileUrl = Environment.authMobileUrl;
  static const String salesUrl = Environment.salesUrl;
  static const String shiftUrl = Environment.shiftUrl;
  static const String userUrl = Environment.userUrl;
  static const String webSocketUrl = Environment.webSocketUrl;

  static const String clientId = Environment.clientId;
  static const String apiKey = Environment.apiKey;
  static const String hashedData = Environment.hashedData;

  static Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'x-client-id': clientId,
    'x-api-key': apiKey,
    'x-hashed-data': hashedData,
  };

  static Map<String, String> getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'x-client-id': clientId,
      'x-api-key': apiKey,
      'x-hashed-data': hashedData,
    };
  }

  static Map<String, String> getAuthHeaders(String token) {
    return {
      ...getDefaultHeaders(),
      'Authorization': 'Bearer $token',
    };
  }
}
