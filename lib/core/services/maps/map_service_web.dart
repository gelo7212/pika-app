import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ignore: uri_does_not_exist
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox_gl;
import '../../config/maps_config.dart';
import 'map_service_interface.dart';
import 'dart:math' as math;

/// Web implementation using mapbox_gl package
class MapServiceWeb implements MapServiceInterface {
  static MapServiceWeb? _instance;
  static MapServiceWeb get instance => _instance ??= MapServiceWeb._();
  MapServiceWeb._();

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize any web-specific map configurations
      await MapsConfig.initializeMapCache();
      _isInitialized = true;
      debugPrint('MapServiceWeb initialized');
    } catch (e) {
      debugPrint('Error initializing MapServiceWeb: $e');
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
    return mapbox_gl.MapboxMap(
      accessToken: MapsConfig.mapboxAccessToken,
      styleString: _mapStyleToString(style),
      initialCameraPosition: mapbox_gl.CameraPosition(
        target: mapbox_gl.LatLng(
          initialCameraPosition.target.latitude,
          initialCameraPosition.target.longitude,
        ),
        zoom: initialCameraPosition.zoom,
        bearing: initialCameraPosition.bearing ?? 0.0,
        tilt: initialCameraPosition.tilt ?? 0.0,
      ),
      onMapCreated: (mapbox_gl.MapboxMapController controller) {
        onMapCreated(controller);
      },
      onMapClick: onMapTap != null
          ? (math.Point<double> point, mapbox_gl.LatLng coordinates) {
              onMapTap(MapLatLng(coordinates.latitude, coordinates.longitude));
            }
          : null,
      onMapLongClick: onMapLongPress != null
          ? (math.Point<double> point, mapbox_gl.LatLng coordinates) {
              onMapLongPress(
                  MapLatLng(coordinates.latitude, coordinates.longitude));
            }
          : null,
      myLocationEnabled: myLocationEnabled,
      compassEnabled: compassEnabled,
      rotateGesturesEnabled: rotateGesturesEnabled,
      scrollGesturesEnabled: scrollGesturesEnabled,
      tiltGesturesEnabled: tiltGesturesEnabled,
      zoomGesturesEnabled: zoomGesturesEnabled,
      doubleClickZoomEnabled: true,
      minMaxZoomPreference: const mapbox_gl.MinMaxZoomPreference(1.0, 22.0),
      // Remove logo and attribution margins for web (not supported)
    );
  }

  @override
  Future<void> animateCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as mapbox_gl.MapboxMapController;
    final update = _convertCameraUpdate(cameraUpdate);

    if (update != null) {
      await controller.animateCamera(update);
    }
  }

  @override
  Future<void> moveCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as mapbox_gl.MapboxMapController;
    final update = _convertCameraUpdate(cameraUpdate);

    if (update != null) {
      await controller.moveCamera(update);
    }
  }

  @override
  Future<void> addMarker(dynamic mapController, MapMarker marker) async {
    if (!isControllerReady(mapController)) return;

    // For web, we'll use circles as markers since symbols can cause issues
    await addCircle(
        mapController,
        MapCircle(
          circleId: marker.markerId,
          center: marker.position,
          radius: 10.0,
          fillColor: const Color(0xFFFF0000),
          strokeColor: const Color(0xFFFFFFFF),
          strokeWidth: 2.0,
        ));
  }

  @override
  Future<void> removeMarker(dynamic mapController, String markerId) async {
    // Since we use circles as markers, remove the circle
    await removeCircle(mapController, markerId);
  }

  @override
  Future<void> addCircle(dynamic mapController, MapCircle circle) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as mapbox_gl.MapboxMapController;

    try {
      await controller.addCircle(
        mapbox_gl.CircleOptions(
          circleRadius: circle.radius,
          circleColor: _colorToHex(circle.fillColor),
          circleStrokeColor: _colorToHex(circle.strokeColor),
          circleStrokeWidth: circle.strokeWidth,
          geometry: mapbox_gl.LatLng(
            circle.center.latitude,
            circle.center.longitude,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error adding circle: $e');
    }
  }

  @override
  Future<void> removeCircle(dynamic mapController, String circleId) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as mapbox_gl.MapboxMapController;

    try {
      // Get all circles and find the one to remove
      final circles = await controller.circles;
      for (final circle in circles) {
        // Note: mapbox_gl doesn't provide direct ID access,
        // so this is a limitation we need to work around
        await controller.removeCircle(circle);
        break; // For now, remove the first circle found
      }
    } catch (e) {
      debugPrint('Error removing circle: $e');
    }
  }

  @override
  Future<MapCameraPosition> getCameraPosition(dynamic mapController) async {
    if (!isControllerReady(mapController)) {
      throw Exception('Map controller not ready');
    }

    // For web implementation, we'll maintain camera position internally
    // since mapbox_gl doesn't provide getCameraPosition
    throw UnimplementedError('getCameraPosition not supported on web platform');
  }

  @override
  bool isControllerReady(dynamic mapController) {
    return mapController != null &&
        mapController is mapbox_gl.MapboxMapController;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('MapServiceWeb disposed');
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

  mapbox_gl.CameraUpdate? _convertCameraUpdate(MapCameraUpdate update) {
    if (update is NewLatLng) {
      return mapbox_gl.CameraUpdate.newLatLng(
        mapbox_gl.LatLng(update.latLng.latitude, update.latLng.longitude),
      );
    } else if (update is NewLatLngZoom) {
      return mapbox_gl.CameraUpdate.newLatLngZoom(
        mapbox_gl.LatLng(update.latLng.latitude, update.latLng.longitude),
        update.zoom,
      );
    } else if (update is NewCameraPosition) {
      return mapbox_gl.CameraUpdate.newCameraPosition(
        mapbox_gl.CameraPosition(
          target: mapbox_gl.LatLng(
            update.position.target.latitude,
            update.position.target.longitude,
          ),
          zoom: update.position.zoom,
          bearing: update.position.bearing ?? 0.0,
          tilt: update.position.tilt ?? 0.0,
        ),
      );
    } else if (update is ZoomIn) {
      return mapbox_gl.CameraUpdate.zoomIn();
    } else if (update is ZoomOut) {
      return mapbox_gl.CameraUpdate.zoomOut();
    } else if (update is ZoomTo) {
      return mapbox_gl.CameraUpdate.zoomTo(update.zoom);
    }

    return null;
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
