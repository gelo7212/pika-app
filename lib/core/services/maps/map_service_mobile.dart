import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox_mobile;
import '../../config/maps_config.dart';
import 'map_service_interface.dart';

/// Mobile implementation using mapbox_maps_flutter package
class MapServiceMobile implements MapServiceInterface {
  static MapServiceMobile? _instance;
  static MapServiceMobile get instance => _instance ??= MapServiceMobile._();
  MapServiceMobile._();

  bool _isInitialized = false;

  // Track annotation managers and their annotations for removal
  final Map<String, mapbox_mobile.PointAnnotationManager> _annotationManagers =
      {};
  final Map<String, mapbox_mobile.PointAnnotation> _annotations = {};
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set Mapbox access token programmatically for mobile
      mapbox_mobile.MapboxOptions.setAccessToken(MapsConfig.mapboxAccessToken);

      // Initialize any mobile-specific map configurations
      await MapsConfig.initializeMapCache();
      _isInitialized = true;
      debugPrint('MapServiceMobile initialized');
    } catch (e) {
      debugPrint('Error initializing MapServiceMobile: $e');
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
    // Use a stable key instead of timestamp to prevent unnecessary recreations
    Widget mapWidget = mapbox_mobile.MapWidget(
      key: const ValueKey('mapbox_mobile_stable'),
      cameraOptions: mapbox_mobile.CameraOptions(
        center: mapbox_mobile.Point(
          coordinates: mapbox_mobile.Position(
            initialCameraPosition.target.longitude,
            initialCameraPosition.target.latitude,
          ),
        ),
        zoom: initialCameraPosition.zoom,
        bearing: initialCameraPosition.bearing,
        pitch: initialCameraPosition.tilt,
      ),
      styleUri: _mapStyleToString(style),
      onMapCreated: (mapbox_mobile.MapboxMap mapboxMap) async {
        debugPrint('Mapbox mobile map created successfully');

        // Set up tap and long press listeners
        _setupGestureListeners(mapboxMap, onMapTap, onMapLongPress);

        onMapCreated(mapboxMap);
      },
      onTapListener: (mapbox_mobile.MapContentGestureContext context) async {
        if (onMapTap != null) {
          try {
            debugPrint('Map tap detected at screen coordinate: ${context.point.coordinates}');
            
            // Convert coordinates to MapLatLng
            final coordinates = context.point.coordinates;
            final mapLatLng = MapLatLng(
              coordinates.lat.toDouble(),
              coordinates.lng.toDouble(),
            );
            
            debugPrint('Map tap converted to coordinates: ${mapLatLng.latitude}, ${mapLatLng.longitude}');
            onMapTap(mapLatLng);
          } catch (e) {
            debugPrint('Error handling map tap: $e');
          }
        }
      },
      onLongTapListener: onMapLongPress != null ? (mapbox_mobile.MapContentGestureContext context) async {
        try {
          debugPrint('Map long press detected at screen coordinate: ${context.point.coordinates}');
          
          // Convert coordinates to MapLatLng
          final coordinates = context.point.coordinates;
          final mapLatLng = MapLatLng(
            coordinates.lat.toDouble(),
            coordinates.lng.toDouble(),
          );
          
          debugPrint('Map long press at coordinates: ${mapLatLng.latitude}, ${mapLatLng.longitude}');
          onMapLongPress(mapLatLng);
        } catch (e) {
          debugPrint('Error handling map long press: $e');
        }
      } : null,
    );

    // If no tap handling is needed, return the map widget directly
    if (onMapTap == null && onMapLongPress == null) {
      return mapWidget;
    }

    // Return the map widget directly - tap handling is done via the map's native events
    return mapWidget;
  }

  /// Set up gesture listeners for map tap and long press
  void _setupGestureListeners(
    mapbox_mobile.MapboxMap mapboxMap,
    Function(MapLatLng)? onMapTap,
    Function(MapLatLng)? onMapLongPress,
  ) {
    // Gesture listeners are now handled natively via onTapListener and onLongTapListener
    // in the MapWidget constructor above
    debugPrint('Gesture listeners set up via native MapWidget parameters');
  }

  @override
  Future<void> animateCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    try {
      final controller = mapController as mapbox_mobile.MapboxMap;
      final cameraOptions = _convertCameraUpdate(cameraUpdate);

      if (cameraOptions != null) {
        await controller.easeTo(
          cameraOptions,
          mapbox_mobile.MapAnimationOptions(duration: 1000),
        );
      }
    } catch (e) {
      debugPrint('Error animating camera on mobile: $e');
    }
  }

  @override
  Future<void> moveCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    try {
      final controller = mapController as mapbox_mobile.MapboxMap;
      final cameraOptions = _convertCameraUpdate(cameraUpdate);

      if (cameraOptions != null) {
        await controller.setCamera(cameraOptions);
      }
    } catch (e) {
      debugPrint('Error moving camera on mobile: $e');
    }
  }

  @override
  Future<void> addMarker(dynamic mapController, MapMarker marker) async {
    if (!isControllerReady(mapController)) {
      debugPrint('Map controller not ready for adding marker');
      return;
    }

    try {
      final controller = mapController as mapbox_mobile.MapboxMap;

      // Remove existing marker with the same ID if it exists
      await removeMarker(mapController, marker.markerId);

      // Create and add a point annotation manager
      final annotationManager =
          await controller.annotations.createPointAnnotationManager();

      // Store the annotation manager for later removal
      _annotationManagers[marker.markerId] = annotationManager;

      // Create the marker with a simple circle that looks like a pin
      final annotation = await annotationManager.create(
        mapbox_mobile.PointAnnotationOptions(
          geometry: mapbox_mobile.Point(
            coordinates: mapbox_mobile.Position(
              marker.position.longitude,
              marker.position.latitude,
            ),
          ),
          // Create a simple colored circle as a pin
          iconColor: Colors.red.value, // Red pin color
          iconSize: 1.5,
          // Optional: Add text label below the pin if title is provided
          textField: marker.title?.isNotEmpty == true ? marker.title! : '📍',
          textSize: marker.title?.isNotEmpty == true ? 10.0 : 16.0,
          textColor: Colors.black.value,
          textHaloColor: Colors.white.value,
          textHaloWidth: 1.0,
          textOffset: [0.0, marker.title?.isNotEmpty == true ? 1.5 : 0.0],
          textAnchor: marker.title?.isNotEmpty == true
              ? mapbox_mobile.TextAnchor.TOP
              : mapbox_mobile.TextAnchor.CENTER,
        ),
      );

      // Store the annotation for later removal
      _annotations[marker.markerId] = annotation;

      debugPrint(
          'Marker with pin added successfully at: ${marker.position.latitude}, ${marker.position.longitude}');
    } catch (e) {
      debugPrint('Error adding marker on mobile: $e');
      // Continue without throwing to prevent app crashes
    }
  }

  @override
  Future<void> removeMarker(dynamic mapController, String markerId) async {
    if (!isControllerReady(mapController)) {
      debugPrint('Map controller not ready for removing marker');
      return;
    }

    try {
      debugPrint('Attempting to remove marker with ID: $markerId');

      // Check if we have the annotation and annotation manager for this marker
      final annotation = _annotations[markerId];
      final annotationManager = _annotationManagers[markerId];

      if (annotation != null && annotationManager != null) {
        // Delete the annotation
        await annotationManager.delete(annotation);

        // Remove from our tracking maps
        _annotations.remove(markerId);

        // Remove the annotation manager
        final controller = mapController as mapbox_mobile.MapboxMap;
        await controller.annotations.removeAnnotationManager(annotationManager);
        _annotationManagers.remove(markerId);

        debugPrint('Marker with ID $markerId removed successfully');
      } else {
        debugPrint('Marker with ID $markerId not found in tracking maps');
      }
    } catch (e) {
      debugPrint('Error removing marker on mobile: $e');
      // Continue without throwing to prevent app crashes
    }
  }

  @override
  Future<void> addCircle(dynamic mapController, MapCircle circle) async {
    if (!isControllerReady(mapController)) return;

    // Placeholder implementation
    debugPrint('addCircle called on mobile (not implemented)');

    /*
    // Uncomment when mapbox_maps_flutter is added
    final controller = mapController as mapbox_mobile.MapboxMap;
    
    await controller.annotations.createCircleAnnotationManager().then((manager) async {
      await manager.create(
        mapbox_mobile.CircleAnnotationOptions(
          geometry: mapbox_mobile.Point(
            coordinates: mapbox_mobile.Position(
              circle.center.longitude,
              circle.center.latitude,
            ),
          ),
          circleRadius: circle.radius,
          circleColor: circle.fillColor.value,
          circleStrokeColor: circle.strokeColor.value,
          circleStrokeWidth: circle.strokeWidth,
        ),
      );
    });
    */
  }

  @override
  Future<void> removeCircle(dynamic mapController, String circleId) async {
    if (!isControllerReady(mapController)) return;

    // Placeholder implementation
    debugPrint('removeCircle called on mobile (not implemented)');

    /*
    // Uncomment when mapbox_maps_flutter is added
    // Implementation would require tracking annotation managers and IDs
    */
  }

  @override
  Future<MapCameraPosition> getCameraPosition(dynamic mapController) async {
    if (!isControllerReady(mapController)) {
      throw Exception('Map controller not ready');
    }

    // Placeholder implementation
    throw UnimplementedError('getCameraPosition not implemented on mobile yet');

    /*
    // Uncomment when mapbox_maps_flutter is added
    final controller = mapController as mapbox_mobile.MapboxMap;
    final cameraState = await controller.getCameraState();
    
    return MapCameraPosition(
      target: MapLatLng(
        cameraState.center.coordinates.lat,
        cameraState.center.coordinates.lng,
      ),
      zoom: cameraState.zoom,
      bearing: cameraState.bearing,
      tilt: cameraState.pitch,
    );
    */
  }

  @override
  bool isControllerReady(dynamic mapController) {
    return mapController != null && mapController is mapbox_mobile.MapboxMap;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('MapServiceMobile disposed');
  }

  String _mapStyleToString(MapStyle style) {
    switch (style) {
      case MapStyle.street:
        return MapsConfig.streetStyle;
      case MapStyle.satellite:
        return MapsConfig.satelliteStyle;
      case MapStyle.light:
        return MapsConfig.lightStyle;
      case MapStyle.dark:
        return MapsConfig.darkStyle;
    }
  }

  mapbox_mobile.CameraOptions? _convertCameraUpdate(MapCameraUpdate update) {
    if (update is NewLatLng) {
      return mapbox_mobile.CameraOptions(
        center: mapbox_mobile.Point(
          coordinates: mapbox_mobile.Position(
            update.latLng.longitude,
            update.latLng.latitude,
          ),
        ),
      );
    } else if (update is NewLatLngZoom) {
      return mapbox_mobile.CameraOptions(
        center: mapbox_mobile.Point(
          coordinates: mapbox_mobile.Position(
            update.latLng.longitude,
            update.latLng.latitude,
          ),
        ),
        zoom: update.zoom,
      );
    } else if (update is NewCameraPosition) {
      return mapbox_mobile.CameraOptions(
        center: mapbox_mobile.Point(
          coordinates: mapbox_mobile.Position(
            update.position.target.longitude,
            update.position.target.latitude,
          ),
        ),
        zoom: update.position.zoom,
        bearing: update.position.bearing,
        pitch: update.position.tilt,
      );
    }
    // Handle zoom operations differently in mobile implementation

    return null;
  }
}
