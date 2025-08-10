import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store_model.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';
import 'address_service.dart';

class StoreService {
  final Dio _dio;
  final String _baseUrl;

  StoreService({
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

  /// Get the nearest store based on coordinates
  Future<Store?> getNearestStore({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await _dio.get(
        '$_baseUrl/stores/nearest',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return Store.fromJson(response.data['data']);
      }
      
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // No store found near the location
        return null;
      }
      rethrow;
    }
  }

  /// Get current device location
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    } 

    return await Geolocator.getCurrentPosition();
  }

  /// Get nearest store using default address or current location
  /// Returns the store and a boolean indicating if current location was used
  Future<({Store? store, bool usedCurrentLocation})> getNearestStoreAuto() async {
    try {
      // First try to get default address
      final addressService = serviceLocator.get<AddressService>();
      final defaultAddress = await addressService.getDefaultAddress();
      
      if (defaultAddress != null) {
        // Use default address coordinates
        final store = await getNearestStore(
          latitude: defaultAddress.latitude,
          longitude: defaultAddress.longitude,
        );
        
        return (store: store, usedCurrentLocation: false);
      }
    } catch (e) {
      // If address service fails, continue to current location
    }
    
    // No default address found, use current location
    try {
      final position = await getCurrentLocation();
      final store = await getNearestStore(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      return (store: store, usedCurrentLocation: true);
    } catch (locationError) {
      rethrow;
    }
  }
}
