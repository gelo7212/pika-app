import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'map_service_interface.dart';
import 'map_service_platform_interface.dart'
    if (dart.library.html) 'map_service_platform_web.dart'
    if (dart.library.io) 'map_service_platform_mobile.dart';

/// Main map service that provides a unified API across all platforms
///
/// Usage:
/// ```dart
/// // Initialize once in your app
/// await MapService.instance.initialize();
///
/// // Create a map widget
/// Widget mapWidget = MapService.instance.createMapWidget(
///   initialCameraPosition: MapCameraPosition(
///     target: MapLatLng(14.5995, 120.9842),
///     zoom: 14.0,
///   ),
///   onMapCreated: (controller) {
///     // Store controller for later use
///   },
///   onMapTap: (latLng) {
///     print('Map tapped at: $latLng');
///   },
/// );
///
/// // Use map operations
/// await MapService.instance.addMarker(controller,
///   MapMarker(
///     markerId: 'marker1',
///     position: MapLatLng(14.5995, 120.9842),
///     title: 'Manila',
///   ),
/// );
/// ```
class MapService implements MapServiceInterface {
  static MapService? _instance;
  static MapService get instance => _instance ??= MapService._();
  MapService._();

  late final MapServiceInterface _platformService;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use conditional imports to get the right platform service
      _platformService = createMapService();

      await _platformService.initialize();
      _isInitialized = true;

      debugPrint(
          'MapService initialized for platform: ${kIsWeb ? 'Web' : 'Mobile'}');
    } catch (e) {
      debugPrint('Error initializing MapService: $e');
      rethrow;
    }
  }

  @override
  Widget createMapWidget({
    required MapCameraPosition initialCameraPosition,
    required Function(dynamic mapController) onMapCreated,
    Function(MapLatLng)? onMapTap,
    Function(MapLatLng)? onMapLongPress,
    bool myLocationEnabled = false,
    bool compassEnabled = true,
    bool rotateGesturesEnabled = true,
    bool scrollGesturesEnabled = true,
    bool tiltGesturesEnabled = true,
    bool zoomGesturesEnabled = true,
    MapStyle style = MapStyle.street,
    EdgeInsets? padding,
  }) {
    _ensureInitialized();

    return _platformService.createMapWidget(
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      onMapTap: onMapTap,
      onMapLongPress: onMapLongPress,
      myLocationEnabled: myLocationEnabled,
      compassEnabled: compassEnabled,
      rotateGesturesEnabled: rotateGesturesEnabled,
      scrollGesturesEnabled: scrollGesturesEnabled,
      tiltGesturesEnabled: tiltGesturesEnabled,
      zoomGesturesEnabled: zoomGesturesEnabled,
      style: style,
      padding: padding,
    );
  }

  @override
  Future<void> animateCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    _ensureInitialized();
    return _platformService.animateCamera(mapController, cameraUpdate);
  }

  @override
  Future<void> moveCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    _ensureInitialized();
    return _platformService.moveCamera(mapController, cameraUpdate);
  }

  @override
  Future<void> addMarker(dynamic mapController, MapMarker marker) async {
    _ensureInitialized();
    return _platformService.addMarker(mapController, marker);
  }

  @override
  Future<void> removeMarker(dynamic mapController, String markerId) async {
    _ensureInitialized();
    return _platformService.removeMarker(mapController, markerId);
  }

  @override
  Future<void> addCircle(dynamic mapController, MapCircle circle) async {
    _ensureInitialized();
    return _platformService.addCircle(mapController, circle);
  }

  @override
  Future<void> removeCircle(dynamic mapController, String circleId) async {
    _ensureInitialized();
    return _platformService.removeCircle(mapController, circleId);
  }

  @override
  Future<MapCameraPosition> getCameraPosition(dynamic mapController) async {
    _ensureInitialized();
    return _platformService.getCameraPosition(mapController);
  }

  @override
  bool isControllerReady(dynamic mapController) {
    _ensureInitialized();
    return _platformService.isControllerReady(mapController);
  }

  @override
  Future<void> dispose() async {
    if (_isInitialized) {
      await _platformService.dispose();
      _isInitialized = false;
    }
  }

  /// Convenience method to create a default camera position for Manila, Philippines
  static MapCameraPosition get defaultCameraPosition => const MapCameraPosition(
        target: MapLatLng(14.5995, 120.9842), // Manila coordinates
        zoom: 14.0,
      );

  /// Convenience method to create camera updates
  static MapCameraUpdate moveToLocation(MapLatLng location, {double? zoom}) {
    if (zoom != null) {
      return MapCameraUpdate.newLatLngZoom(location, zoom);
    } else {
      return MapCameraUpdate.newLatLng(location);
    }
  }

  /// Convenience method to create a marker
  static MapMarker createMarker({
    required String id,
    required MapLatLng position,
    String? title,
    String? snippet,
    Widget? infoWindow,
  }) {
    return MapMarker(
      markerId: id,
      position: position,
      title: title,
      snippet: snippet,
      infoWindow: infoWindow,
    );
  }

  /// Convenience method to create a circle
  static MapCircle createCircle({
    required String id,
    required MapLatLng center,
    required double radius,
    Color fillColor = const Color(0x80FF0000),
    Color strokeColor = const Color(0xFFFF0000),
    double strokeWidth = 2.0,
  }) {
    return MapCircle(
      circleId: id,
      center: center,
      radius: radius,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    );
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('MapService not initialized. Call initialize() first.');
    }
  }

  /// Get the current platform (for debugging)
  String get currentPlatform => kIsWeb ? 'Web' : 'Mobile';

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
}
