import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';
import '../models/delivery_status_model.dart';

class DeliveryService {
  final Dio _dio;
  final String _baseUrl;

  DeliveryService()
      : _dio = Dio(),
        _baseUrl = ApiConfig.salesUrl {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
    ));
  }

  Future<Map<String, String>> _getHeaders() async {
    final tokenService = serviceLocator<TokenServiceInterface>();
    final tokens = await tokenService.getStoredTokens();
    
    return {
      'Content-Type': 'application/json',
      'x-api-key': ApiConfig.apiKey,
      'x-client-id': ApiConfig.clientId,
      'x-hashed-data': ApiConfig.hashedData,
      if (tokens?.userAccessToken != null) 'Authorization': 'Bearer ${tokens!.userAccessToken}',
    };
  }

  /// Get delivery status for a specific order
  Future<DeliveryStatusResponse> getDeliveryStatus(String orderId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await _dio.get(
        '$_baseUrl/deliveries/status/$orderId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        return DeliveryStatusResponse.fromJson(data);
      } else {
        throw Exception('Failed to get delivery status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to get delivery status';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting delivery status: $e');
    }
  }

  /// Get multiple delivery statuses for order tracking
  Future<List<DeliveryStatusResponse>> getMultipleDeliveryStatuses(
      List<String> orderIds) async {
    try {
      final List<DeliveryStatusResponse> results = [];
      
      // Make concurrent requests for better performance
      final futures = orderIds.map((orderId) => getDeliveryStatus(orderId));
      final responses = await Future.wait(futures);
      
      results.addAll(responses);
      return results;
    } catch (e) {
      throw Exception('Error getting multiple delivery statuses: $e');
    }
  }

  /// Check if order has delivery tracking available
  Future<bool> hasDeliveryTracking(String orderId) async {
    try {
      await getDeliveryStatus(orderId);
      return true;
    } catch (e) {
      // If we get an error, assume tracking is not available
      return false;
    }
  }
}
