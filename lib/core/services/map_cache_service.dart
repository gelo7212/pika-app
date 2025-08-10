import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'maps/map_service_interface.dart';

/// Service for caching map-related data including tiles, geocoding results, and configurations
class MapCacheService {
  static MapCacheService? _instance;
  static MapCacheService get instance => _instance ??= MapCacheService._();
  MapCacheService._();

  static const String _geocodingBoxName = 'geocoding_cache';
  static const String _mapConfigBoxName = 'map_config_cache';
  static const String _locationBoxName = 'location_cache';

  Box<dynamic>? _geocodingBox;
  Box<dynamic>? _mapConfigBox;
  Box<dynamic>? _locationBox;

  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }

      // Open cache boxes
      _geocodingBox = await Hive.openBox(_geocodingBoxName);
      _mapConfigBox = await Hive.openBox(_mapConfigBoxName);
      _locationBox = await Hive.openBox(_locationBoxName);

      _isInitialized = true;
      debugPrint('MapCacheService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing MapCacheService: $e');
      rethrow;
    }
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // MARK: - Geocoding Cache

  /// Cache geocoding result for a location
  Future<void> cacheGeocodingResult(
      double latitude, double longitude, String address) async {
    await _ensureInitialized();

    try {
      final key = _getLocationKey(latitude, longitude);
      final data = {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _geocodingBox!.put(key, data);
      debugPrint('Cached geocoding result for $key: $address');
    } catch (e) {
      debugPrint('Error caching geocoding result: $e');
    }
  }

  /// Get cached geocoding result for a location
  Future<String?> getCachedGeocodingResult(
      double latitude, double longitude) async {
    await _ensureInitialized();

    try {
      final key = _getLocationKey(latitude, longitude);
      final data = _geocodingBox!.get(key);

      if (data != null && data is Map) {
        final timestamp = data['timestamp'] as int?;
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - (timestamp ?? 0);

        // Cache valid for 7 days
        if (cacheAge < (7 * 24 * 60 * 60 * 1000)) {
          debugPrint('Using cached geocoding result for $key');
          return data['address'] as String?;
        } else {
          // Cache expired, remove it
          await _geocodingBox!.delete(key);
          debugPrint('Geocoding cache expired for $key');
        }
      }
    } catch (e) {
      debugPrint('Error getting cached geocoding result: $e');
    }

    return null;
  }

  // MARK: - Location Data Cache

  /// Cache current location
  Future<void> cacheCurrentLocation(MapLatLng location) async {
    await _ensureInitialized();

    try {
      final data = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _locationBox!.put('current_location', data);
      debugPrint(
          'Cached current location: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      debugPrint('Error caching current location: $e');
    }
  }

  /// Get cached current location
  Future<MapLatLng?> getCachedCurrentLocation() async {
    await _ensureInitialized();

    try {
      final data = _locationBox!.get('current_location');

      if (data != null && data is Map) {
        final timestamp = data['timestamp'] as int?;
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - (timestamp ?? 0);

        // Cache valid for 30 minutes
        if (cacheAge < (30 * 60 * 1000)) {
          final lat = data['latitude'] as double?;
          final lng = data['longitude'] as double?;

          if (lat != null && lng != null) {
            debugPrint('Using cached current location: $lat, $lng');
            return MapLatLng(lat, lng);
          }
        } else {
          // Cache expired, remove it
          await _locationBox!.delete('current_location');
          debugPrint('Current location cache expired');
        }
      }
    } catch (e) {
      debugPrint('Error getting cached current location: $e');
    }

    return null;
  }

  // MARK: - Map Configuration Cache

  /// Cache map configuration settings
  Future<void> cacheMapConfig(String key, Map<String, dynamic> config) async {
    await _ensureInitialized();

    try {
      final data = {
        ...config,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _mapConfigBox!.put(key, data);
      debugPrint('Cached map config for $key');
    } catch (e) {
      debugPrint('Error caching map config: $e');
    }
  }

  /// Get cached map configuration
  Future<Map<String, dynamic>?> getCachedMapConfig(String key) async {
    await _ensureInitialized();

    try {
      final data = _mapConfigBox!.get(key);

      if (data != null && data is Map) {
        final timestamp = data['timestamp'] as int?;
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - (timestamp ?? 0);

        // Cache valid for 1 day
        if (cacheAge < (24 * 60 * 60 * 1000)) {
          debugPrint('Using cached map config for $key');
          final config = Map<String, dynamic>.from(data);
          config.remove('timestamp'); // Remove timestamp from returned config
          return config;
        } else {
          // Cache expired, remove it
          await _mapConfigBox!.delete(key);
          debugPrint('Map config cache expired for $key');
        }
      }
    } catch (e) {
      debugPrint('Error getting cached map config: $e');
    }

    return null;
  }

  // MARK: - Cache Management

  /// Clear all cache data
  Future<void> clearAllCache() async {
    await _ensureInitialized();

    try {
      await _geocodingBox!.clear();
      await _mapConfigBox!.clear();
      await _locationBox!.clear();

      debugPrint('All map cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _ensureInitialized();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Clear expired geocoding cache (7 days)
      final geocodingKeys = _geocodingBox!.keys.toList();
      for (final key in geocodingKeys) {
        final data = _geocodingBox!.get(key);
        if (data is Map && data['timestamp'] != null) {
          final age = now - (data['timestamp'] as int);
          if (age > (7 * 24 * 60 * 60 * 1000)) {
            await _geocodingBox!.delete(key);
          }
        }
      }

      // Clear expired location cache (30 minutes)
      final locationKeys = _locationBox!.keys.toList();
      for (final key in locationKeys) {
        final data = _locationBox!.get(key);
        if (data is Map && data['timestamp'] != null) {
          final age = now - (data['timestamp'] as int);
          if (age > (30 * 60 * 1000)) {
            await _locationBox!.delete(key);
          }
        }
      }

      // Clear expired map config cache (1 day)
      final configKeys = _mapConfigBox!.keys.toList();
      for (final key in configKeys) {
        final data = _mapConfigBox!.get(key);
        if (data is Map && data['timestamp'] != null) {
          final age = now - (data['timestamp'] as int);
          if (age > (24 * 60 * 60 * 1000)) {
            await _mapConfigBox!.delete(key);
          }
        }
      }

      debugPrint('Expired cache entries cleared');
    } catch (e) {
      debugPrint('Error clearing expired cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    try {
      return {
        'geocoding_entries': _geocodingBox!.length,
        'location_entries': _locationBox!.length,
        'config_entries': _mapConfigBox!.length,
        'total_entries': _geocodingBox!.length +
            _locationBox!.length +
            _mapConfigBox!.length,
      };
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }

  // MARK: - Utility Methods

  /// Generate a consistent key for location-based caching
  String _getLocationKey(double latitude, double longitude) {
    // Round to 6 decimal places for reasonable precision while allowing cache hits
    final roundedLat = (latitude * 1000000).round() / 1000000;
    final roundedLng = (longitude * 1000000).round() / 1000000;
    return '${roundedLat}_$roundedLng';
  }

  /// Dispose and close all boxes
  Future<void> dispose() async {
    try {
      await _geocodingBox?.close();
      await _mapConfigBox?.close();
      await _locationBox?.close();

      _geocodingBox = null;
      _mapConfigBox = null;
      _locationBox = null;
      _isInitialized = false;

      debugPrint('MapCacheService disposed');
    } catch (e) {
      debugPrint('Error disposing MapCacheService: $e');
    }
  }
}
