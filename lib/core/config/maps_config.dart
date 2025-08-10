import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../services/map_cache_service.dart';
import '../services/maps/map_service_interface.dart';

class MapsConfig {
  // Replace this with your actual Mapbox Access Token
  // Get it from: https://account.mapbox.com/access-tokens/
  static const String _mapboxAccessToken =
      'sk.eyJ1IjoiZ2VsbzcyMTI3IiwiYSI6ImNtZTVwOW1ieDA4N2QybHIxYnBwbTgwNzcifQ.DcAl0plhQ8nf3fbBgJDH-g';

  static String get mapboxAccessToken {
    // This appears to be a valid token for user 'gelo72127'
    // Removing the placeholder warning as this seems to be a real token
    return _mapboxAccessToken;
  }

  // Default location (Manila, Philippines)
  static const double defaultLatitude = 14.5995;
  static const double defaultLongitude = 120.9842;

  // Map settings
  static const double defaultZoom = 14.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 22.0;

  // Mapbox style URLs
  static const String streetStyle = 'mapbox://styles/mapbox/streets-v12';
  static const String satelliteStyle =
      'mapbox://styles/mapbox/satellite-streets-v12';
  static const String lightStyle = 'mapbox://styles/mapbox/light-v11';
  static const String darkStyle = 'mapbox://styles/mapbox/dark-v11';

  // Cache configuration
  static const Duration geocodingCacheExpiry = Duration(days: 7);
  static const Duration locationCacheExpiry = Duration(minutes: 30);
  static const Duration mapConfigCacheExpiry = Duration(days: 1);

  // Performance settings
  static const int mapTileCacheSize = 100; // MB
  static const bool enableOfflineMode = true;
  static const Duration mapLoadTimeout = Duration(seconds: 30);

  // Camera animation settings with platform-specific optimizations
  static Duration get cameraAnimationDuration => kIsWeb
      ? const Duration(milliseconds: 800)
      : const Duration(milliseconds: 500);

  static Duration get markerAddDelay => kIsWeb
      ? const Duration(milliseconds: 300)
      : const Duration(milliseconds: 100);

  // Default camera position
  static MapCameraPosition get defaultCameraPosition => const MapCameraPosition(
        target: MapLatLng(defaultLatitude, defaultLongitude),
        zoom: defaultZoom,
      );

  /// Get cached map style or return default
  static Future<String> getCachedMapStyle({String style = streetStyle}) async {
    try {
      final cachedConfig =
          await MapCacheService.instance.getCachedMapConfig('map_style');
      if (cachedConfig != null && cachedConfig['style'] != null) {
        debugPrint('Using cached map style');
        return cachedConfig['style'] as String;
      }
    } catch (e) {
      debugPrint('Error getting cached map style: $e');
    }

    // Cache the default style
    try {
      await MapCacheService.instance
          .cacheMapConfig('map_style', {'style': style});
    } catch (e) {
      debugPrint('Error caching map style: $e');
    }

    return style;
  }

  /// Get cached default location or return hardcoded default
  static Future<MapLatLng> getCachedDefaultLocation() async {
    try {
      final cachedLocation =
          await MapCacheService.instance.getCachedCurrentLocation();
      if (cachedLocation != null) {
        debugPrint('Using cached default location');
        return cachedLocation;
      }
    } catch (e) {
      debugPrint('Error getting cached default location: $e');
    }

    return const MapLatLng(defaultLatitude, defaultLongitude);
  }

  /// Cache map configuration
  static Future<void> cacheMapConfiguration(Map<String, dynamic> config) async {
    try {
      await MapCacheService.instance.cacheMapConfig('general_config', config);
      debugPrint('Map configuration cached');
    } catch (e) {
      debugPrint('Error caching map configuration: $e');
    }
  }

  /// Get optimized map settings based on platform and performance
  static Map<String, dynamic> getOptimizedMapSettings() {
    return {
      'styleString': streetStyle,
      'myLocationEnabled': true,
      'compassEnabled': true,
      'rotateGesturesEnabled': true,
      'scrollGesturesEnabled': true,
      'tiltGesturesEnabled': true,
      'zoomGesturesEnabled': true,
      'doubleClickZoomEnabled': true,
      // Performance settings (these will be interpreted by platform implementations)
      'minZoom': minZoom,
      'maxZoom': maxZoom,
    };
  }

  /// Initialize map caching system
  static Future<void> initializeMapCache() async {
    try {
      await MapCacheService.instance.initialize();
      debugPrint('Map cache system initialized');

      // Clean up expired cache entries
      await MapCacheService.instance.clearExpiredCache();
    } catch (e) {
      debugPrint('Error initializing map cache: $e');
    }
  }
}
