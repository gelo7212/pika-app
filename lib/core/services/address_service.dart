import 'package:dio/dio.dart';
import '../models/address_model.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class AddressService {
  final Dio _dio;
  final String _baseUrl;

  AddressService({
    required Dio dio,
    required String baseUrl,
  }) : _dio = dio, _baseUrl = baseUrl;

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

  /// Get all addresses for the current user
  Future<List<Address>> getAddresses() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/addresses',
        options: Options(headers: headers),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((json) => Address.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load addresses');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return []; // No addresses found
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load addresses: $e');
    }
  }
  // get default address
  Future<Address?> getDefaultAddress() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/addresses/default',
        options: Options(headers: headers),
      );
      
      if (response.statusCode == 200) {
        return Address.fromJson(response.data['data'] ?? response.data);
      } else {
        return null; // No default address found
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No default address found
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load default address: $e');
    }
  }

  /// Get a specific address by ID
  Future<Address> getAddress(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/addresses/$id',
        options: Options(headers: headers),
      );
      
      if (response.statusCode == 200) {
        return Address.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to load address');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Address not found');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load address: $e');
    }
  }

  /// Create a new address
  Future<Address> createAddress({
    required String name,
    required String address,
    required double longitude,
    required double latitude,
    required String phone,
    bool isDefault = false,
  }) async {
    try {
      final requestData = {
        'name': name,
        'address': address,
        'longitude': longitude,
        'latitude': latitude,
        'phone': phone,
        'isDefault': isDefault,
      };

      final headers = await _getHeaders();
      final response = await _dio.post(
        '$_baseUrl/addresses',
        data: requestData,
        options: Options(headers: headers),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Address.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to create address');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to create address';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create address: $e');
    }
  }

  /// Update an existing address
  Future<Address> updateAddress({
    required String id,
    required String name,
    required String address,
    required double longitude,
    required double latitude,
    required String phone,
    bool isDefault = false,
  }) async {
    try {
      final requestData = {
        'name': name,
        'address': address,
        'longitude': longitude,
        'latitude': latitude,
        'phone': phone,
        'isDefault': isDefault,
      };

      final headers = await _getHeaders();
      final response = await _dio.put(
        '$_baseUrl/addresses/$id',
        data: requestData,
        options: Options(headers: headers),
      );
      
      if (response.statusCode == 200) {
        return Address.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to update address');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to update address';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.delete(
        '$_baseUrl/addresses/$id',
        options: Options(headers: headers),
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete address');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Address not found');
      }
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to delete address';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  /// Set an address as default
  Future<void> setDefaultAddress(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.put(
        '$_baseUrl/addresses/$id/default',
        options: Options(headers: headers),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to set default address');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to set default address';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }
}
