import 'package:flutter/widgets.dart';

/// Geographic coordinates representation
class MapLatLng {
  final double latitude;
  final double longitude;

  const MapLatLng(this.latitude, this.longitude);

  @override
  String toString() => 'MapLatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapLatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Camera position for map viewing
class MapCameraPosition {
  final MapLatLng target;
  final double zoom;
  final double? bearing;
  final double? tilt;

  const MapCameraPosition({
    required this.target,
    required this.zoom,
    this.bearing,
    this.tilt,
  });
}

/// Camera update operations
abstract class MapCameraUpdate {
  static MapCameraUpdate newLatLng(MapLatLng latLng) => NewLatLng(latLng);

  static MapCameraUpdate newLatLngZoom(MapLatLng latLng, double zoom) =>
      NewLatLngZoom(latLng, zoom);

  static MapCameraUpdate newCameraPosition(MapCameraPosition position) =>
      NewCameraPosition(position);

  static MapCameraUpdate zoomIn() => ZoomIn();
  static MapCameraUpdate zoomOut() => ZoomOut();
  static MapCameraUpdate zoomTo(double zoom) => ZoomTo(zoom);
}

class NewLatLng extends MapCameraUpdate {
  final MapLatLng latLng;
  NewLatLng(this.latLng);
}

class NewLatLngZoom extends MapCameraUpdate {
  final MapLatLng latLng;
  final double zoom;
  NewLatLngZoom(this.latLng, this.zoom);
}

class NewCameraPosition extends MapCameraUpdate {
  final MapCameraPosition position;
  NewCameraPosition(this.position);
}

class ZoomIn extends MapCameraUpdate {}

class ZoomOut extends MapCameraUpdate {}

class ZoomTo extends MapCameraUpdate {
  final double zoom;
  ZoomTo(this.zoom);
}

/// Map marker representation
class MapMarker {
  final String markerId;
  final MapLatLng position;
  final String? title;
  final String? snippet;
  final Widget? infoWindow;

  const MapMarker({
    required this.markerId,
    required this.position,
    this.title,
    this.snippet,
    this.infoWindow,
  });
}

/// Map circle representation
class MapCircle {
  final String circleId;
  final MapLatLng center;
  final double radius;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const MapCircle({
    required this.circleId,
    required this.center,
    required this.radius,
    this.fillColor = const Color(0x80FF0000),
    this.strokeColor = const Color(0xFFFF0000),
    this.strokeWidth = 2.0,
  });
}

/// Map style options
enum MapStyle {
  street,
  satellite,
  light,
  dark,
}

/// Map type for different platforms
enum MapType {
  normal,
  satellite,
  terrain,
  hybrid,
}

/// Abstract interface for map services
abstract class MapServiceInterface {
  /// Initialize the map service
  Future<void> initialize();

  /// Create a map widget
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
  });

  /// Animate camera to new position
  Future<void> animateCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate);

  /// Move camera to new position
  Future<void> moveCamera(dynamic mapController, MapCameraUpdate cameraUpdate);

  /// Add a marker to the map
  Future<void> addMarker(dynamic mapController, MapMarker marker);

  /// Remove a marker from the map
  Future<void> removeMarker(dynamic mapController, String markerId);

  /// Add a circle to the map
  Future<void> addCircle(dynamic mapController, MapCircle circle);

  /// Remove a circle from the map
  Future<void> removeCircle(dynamic mapController, String circleId);

  /// Get current camera position
  Future<MapCameraPosition> getCameraPosition(dynamic mapController);

  /// Check if controller is valid and ready
  bool isControllerReady(dynamic mapController);

  /// Dispose resources
  Future<void> dispose();
}
