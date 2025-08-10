import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:dio/dio.dart';
import '../config/maps_config.dart';
import './map_cache_service.dart';
import 'maps/map_service_interface.dart' show MapLatLng;

/// Service for cached geocoding operations with fallback strategies
class CachedGeocodingService {
  static CachedGeocodingService? _instance;
  static CachedGeocodingService get instance =>
      _instance ??= CachedGeocodingService._();
  CachedGeocodingService._();

  final Dio _dio = Dio();

  /// Reverse geocode with caching
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      // Check cache first
      final cachedResult = await MapCacheService.instance
          .getCachedGeocodingResult(latitude, longitude);

      if (cachedResult != null) {
        return cachedResult;
      }

      // Try standard geocoding first
      String? result = await _tryStandardGeocoding(latitude, longitude);

      // If standard geocoding fails, try Mapbox
      if (result == null) {
        result = await _tryMapboxReverseGeocoding(latitude, longitude);
      }

      // If both fail, create coordinate fallback
      if (result == null) {
        result = _createCoordinateFallback(latitude, longitude);
      }

      // Cache the result if we got one
      if (result.isNotEmpty) {
        await MapCacheService.instance
            .cacheGeocodingResult(latitude, longitude, result);
      }

      return result;
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
      return _createCoordinateFallback(latitude, longitude);
    }
  }

  /// Try standard geocoding package
  Future<String?> _tryStandardGeocoding(
      double latitude, double longitude) async {
    try {
      debugPrint('Attempting standard geocoding for: $latitude, $longitude');

      final placemarks = await geocoding
          .placemarkFromCoordinates(
            latitude,
            longitude,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Geocoding timeout'),
          );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = _formatPlacemarkAddress(placemark);

        if (address.isNotEmpty) {
          debugPrint('Standard geocoding successful: $address');
          return address;
        }
      }

      debugPrint('Standard geocoding returned no valid address');
      return null;
    } catch (e) {
      debugPrint('Standard geocoding failed: $e');
      return null;
    }
  }

  /// Try Mapbox reverse geocoding
  Future<String?> _tryMapboxReverseGeocoding(
      double latitude, double longitude) async {
    try {
      debugPrint(
          'Attempting Mapbox reverse geocoding for: $latitude, $longitude');

      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json';
      final response = await _dio.get(
        url,
        queryParameters: {
          'access_token': MapsConfig.mapboxAccessToken,
          'limit': '1',
          'types': 'address,poi',
          'language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;

        if (features != null && features.isNotEmpty) {
          final feature = features.first as Map<String, dynamic>;
          final placeName = feature['place_name'] as String?;
          final text = feature['text'] as String?;

          final address = placeName ?? text;
          if (address != null && address.isNotEmpty) {
            debugPrint('Mapbox geocoding successful: $address');
            return address;
          }
        }
      }

      debugPrint('Mapbox geocoding returned no valid address');
      return null;
    } catch (e) {
      debugPrint('Mapbox geocoding failed: $e');
      return null;
    }
  }

  /// Format placemark into readable address
  String _formatPlacemarkAddress(geocoding.Placemark placemark) {
    final addressComponents = <String>[];

    // Helper function to safely add non-null, non-empty strings
    void addIfValid(String? component) {
      if (component != null &&
          component.trim().isNotEmpty &&
          component.trim() != 'null' &&
          component.trim() != 'undefined') {
        addressComponents.add(component.trim());
      }
    }

    // Build address from most specific to least specific
    if (placemark.subThoroughfare != null &&
        placemark.thoroughfare != null &&
        placemark.subThoroughfare!.isNotEmpty &&
        placemark.thoroughfare!.isNotEmpty) {
      addIfValid('${placemark.subThoroughfare} ${placemark.thoroughfare}');
    } else {
      addIfValid(placemark.thoroughfare);
      addIfValid(placemark.street);
      // Only use name if it looks like a street address
      if (placemark.name != null && !placemark.name!.contains('+')) {
        addIfValid(placemark.name);
      }
    }

    // Add area information
    addIfValid(placemark.subLocality);
    addIfValid(placemark.locality);
    addIfValid(placemark.subAdministrativeArea);
    addIfValid(placemark.administrativeArea);
    addIfValid(placemark.postalCode);
    addIfValid(placemark.country);

    return addressComponents.join(', ');
  }

  /// Create coordinate fallback address
  String _createCoordinateFallback(double latitude, double longitude) {
    // Check if coordinates are in Philippines area for better context
    if (latitude >= 4.0 &&
        latitude <= 21.0 &&
        longitude >= 116.0 &&
        longitude <= 127.0) {
      return 'Address near ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} (Philippines)';
    } else {
      return 'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    }
  }

  /// Forward geocoding with caching
  Future<List<MapLatLng>> forwardGeocode(String address) async {
    try {
      debugPrint('Forward geocoding for: $address');

      // Try standard geocoding
      final locations = await geocoding
          .locationFromAddress(address)
          .timeout(const Duration(seconds: 15));

      final results = locations
          .map((loc) => MapLatLng(loc.latitude, loc.longitude))
          .toList();

      debugPrint('Forward geocoding found ${results.length} locations');
      return results;
    } catch (e) {
      debugPrint('Forward geocoding failed: $e');
      return [];
    }
  }

  /// Clear geocoding cache
  Future<void> clearCache() async {
    try {
      await MapCacheService.instance.clearAllCache();
      debugPrint('Geocoding cache cleared');
    } catch (e) {
      debugPrint('Error clearing geocoding cache: $e');
    }
  }

  /// Get geocoding cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await MapCacheService.instance.getCacheStats();
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }
}
