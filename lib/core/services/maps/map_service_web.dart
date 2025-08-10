import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../config/maps_config.dart';
import 'map_service_interface.dart';

/// StatefulWidget wrapper for FlutterMap to handle rebuilds properly
class _FlutterMapWrapper extends StatefulWidget {
  final MapController? mapController;
  final MapCameraPosition initialCameraPosition;
  final Function(dynamic mapController) onMapCreated;
  final Function(MapLatLng)? onMapTap;
  final Function(MapLatLng)? onMapLongPress;
  final bool myLocationEnabled;
  final bool compassEnabled;
  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool zoomGesturesEnabled;
  final MapStyle style;
  final EdgeInsets? padding;
  final List<Marker> markers;
  final List<CircleMarker> circles;
  final Set<MapController> createdControllers;
  final VoidCallback? onUpdateRequested;

  const _FlutterMapWrapper({
    super.key,
    required this.mapController,
    required this.initialCameraPosition,
    required this.onMapCreated,
    this.onMapTap,
    this.onMapLongPress,
    this.myLocationEnabled = false,
    this.compassEnabled = true,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.style = MapStyle.street,
    this.padding,
    required this.markers,
    required this.circles,
    required this.createdControllers,
    this.onUpdateRequested,
  });

  @override
  State<_FlutterMapWrapper> createState() => _FlutterMapWrapperState();
}

class _FlutterMapWrapperState extends State<_FlutterMapWrapper> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    
    // Create controller if not provided
    _mapController = widget.mapController ?? MapController();
    
    // Initialize collections for this controller if not already done
    if (!MapServiceWeb.instance._controllerMarkers.containsKey(_mapController)) {
      MapServiceWeb.instance._controllerMarkers[_mapController] = <String, Marker>{};
      MapServiceWeb.instance._controllerCircles[_mapController] = <String, CircleMarker>{};
    }
    
    // Register for updates
    MapServiceWeb.instance._updateCallbacks[_mapController] = () {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild with new markers/circles
        });
      }
    };
  }

  @override
  void dispose() {
    // Clean up
    MapServiceWeb.instance._updateCallbacks.remove(_mapController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current markers and circles for this controller
    final currentMarkers = MapServiceWeb.instance._controllerMarkers[_mapController]?.values.toList() ?? [];
    final currentCircles = MapServiceWeb.instance._controllerCircles[_mapController]?.values.toList() ?? [];
    
    final mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: latlong.LatLng(
          widget.initialCameraPosition.target.latitude,
          widget.initialCameraPosition.target.longitude,
        ),
        initialZoom: widget.initialCameraPosition.zoom,
        minZoom: MapsConfig.minZoom,
        maxZoom: MapsConfig.maxZoom,
        onMapReady: () {
          // Only call onMapCreated once per controller
          if (!widget.createdControllers.contains(_mapController)) {
            widget.createdControllers.add(_mapController);
            debugPrint('FlutterMap ready, calling onMapCreated');
            widget.onMapCreated(_mapController);
          } else {
            debugPrint('FlutterMap ready, but onMapCreated already called for this controller');
          }
        },
        onTap: widget.onMapTap != null
            ? (tapPosition, point) {
                widget.onMapTap!(MapLatLng(point.latitude, point.longitude));
              }
            : null,
        onLongPress: widget.onMapLongPress != null
            ? (tapPosition, point) {
                widget.onMapLongPress!(MapLatLng(point.latitude, point.longitude));
              }
            : null,
        interactionOptions: InteractionOptions(
          flags: _buildInteractionFlags(
            rotateGesturesEnabled: widget.rotateGesturesEnabled,
            scrollGesturesEnabled: widget.scrollGesturesEnabled,
            zoomGesturesEnabled: widget.zoomGesturesEnabled,
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _getTileUrlTemplate(widget.style),
          userAgentPackageName: 'com.picka.esbi',
          maxZoom: MapsConfig.maxZoom,
          tileBuilder: _darkModeTileBuilder,
        ),
        MarkerLayer(
          markers: currentMarkers,
        ),
        CircleLayer(
          circles: currentCircles,
        ),
        // Add attribution widget
        SimpleAttributionWidget(
          source: const Text('© OpenStreetMap contributors'),
        ),
      ],
    );

    // Wrap with zoom controls if zoom gestures are enabled
    if (widget.zoomGesturesEnabled) {
      return Stack(
        children: [
          mapWidget,
          // Custom zoom controls in the bottom right
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return mapWidget;
  }

  int _buildInteractionFlags({
    required bool rotateGesturesEnabled,
    required bool scrollGesturesEnabled,
    required bool zoomGesturesEnabled,
  }) {
    int flags = InteractiveFlag.none;
    
    if (scrollGesturesEnabled) {
      flags |= InteractiveFlag.drag;
    }
    if (zoomGesturesEnabled) {
      flags |= InteractiveFlag.pinchZoom | 
               InteractiveFlag.doubleTapZoom | 
               InteractiveFlag.scrollWheelZoom;
    }
    if (rotateGesturesEnabled) {
      flags |= InteractiveFlag.rotate;
    }
    
    // Always enable basic pan and zoom for web usability
    flags |= InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.scrollWheelZoom;
    
    return flags;
  }

  String _getTileUrlTemplate(MapStyle style) {
    switch (style) {
      case MapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapStyle.dark:
        return 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
      case MapStyle.light:
        return 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png';
      case MapStyle.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    // Optional: Add dark mode filtering if needed
    return tileWidget;
  }
}

/// Web implementation using flutter_map package
class MapServiceWeb implements MapServiceInterface {
  static MapServiceWeb? _instance;
  static MapServiceWeb get instance => _instance ??= MapServiceWeb._();
  MapServiceWeb._();

  bool _isInitialized = false;
  
  // Track markers and circles per controller instance
  final Map<MapController, Map<String, Marker>> _controllerMarkers = {};
  final Map<MapController, Map<String, CircleMarker>> _controllerCircles = {};
  
  // Track created controllers to prevent multiple callbacks
  final Set<MapController> _createdControllers = {};
  
  // Track update callbacks to force widget rebuilds
  final Map<MapController, VoidCallback?> _updateCallbacks = {};

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      debugPrint('MapServiceWeb initialized with flutter_map');
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
    // Use a stable key that doesn't change frequently to prevent unnecessary widget recreations
    final stableKey = ValueKey('flutter_map_web_stable');
    
    // Create a StatefulWidget wrapper that will handle its own controller lifecycle
    return _FlutterMapWrapper(
      key: stableKey,
      mapController: null, // Let the wrapper create and manage its own controller
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
      markers: [], // Start with empty markers
      circles: [], // Start with empty circles
      createdControllers: _createdControllers,
      onUpdateRequested: null, // Will be set by the wrapper
    );
  }

  @override
  Future<void> animateCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    final (center, zoom) = _convertCameraUpdate(cameraUpdate, controller);

    try {
      if (center != null && zoom != null) {
        // Both center and zoom - use move with animated transition
        controller.move(center, zoom);
      } else if (center != null) {
        // Only center - use move with animated transition
        controller.move(center, controller.camera.zoom);
      } else if (zoom != null) {
        // Only zoom - use move with animated transition
        controller.move(controller.camera.center, zoom);
      }
    } catch (e) {
      debugPrint('Error animating camera on web: $e');
    }
  }

  @override
  Future<void> moveCamera(
      dynamic mapController, MapCameraUpdate cameraUpdate) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    final (center, zoom) = _convertCameraUpdate(cameraUpdate, controller);

    try {
      if (center != null && zoom != null) {
        // Both center and zoom
        controller.move(center, zoom);
      } else if (center != null) {
        // Only center
        controller.move(center, controller.camera.zoom);
      } else if (zoom != null) {
        // Only zoom
        controller.move(controller.camera.center, zoom);
      }
    } catch (e) {
      debugPrint('Error moving camera on web: $e');
    }
  }

  @override
  Future<void> addMarker(dynamic mapController, MapMarker marker) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    final flutterMapMarker = Marker(
      point: latlong.LatLng(
        marker.position.latitude,
        marker.position.longitude,
      ),
      width: 40.0,
      height: 40.0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.location_on,
          color: Colors.white,
          size: 20,
        ),
      ),
    );

    // Initialize marker map if needed
    _controllerMarkers[controller] ??= <String, Marker>{};
    _controllerMarkers[controller]![marker.markerId] = flutterMapMarker;
    _triggerMapUpdate(controller);
  }

  @override
  Future<void> removeMarker(dynamic mapController, String markerId) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    _controllerMarkers[controller]?.remove(markerId);
    _triggerMapUpdate(controller);
  }

  @override
  Future<void> addCircle(dynamic mapController, MapCircle circle) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    final flutterMapCircle = CircleMarker(
      point: latlong.LatLng(
        circle.center.latitude,
        circle.center.longitude,
      ),
      radius: circle.radius,
      color: circle.fillColor.withOpacity(0.3),
      borderColor: circle.strokeColor,
      borderStrokeWidth: circle.strokeWidth,
      useRadiusInMeter: true,
    );

    // Initialize circle map if needed
    _controllerCircles[controller] ??= <String, CircleMarker>{};
    _controllerCircles[controller]![circle.circleId] = flutterMapCircle;
    _triggerMapUpdate(controller);
  }

  @override
  Future<void> removeCircle(dynamic mapController, String circleId) async {
    if (!isControllerReady(mapController)) return;

    final controller = mapController as MapController;
    _controllerCircles[controller]?.remove(circleId);
    _triggerMapUpdate(controller);
  }

  @override
  Future<MapCameraPosition> getCameraPosition(dynamic mapController) async {
    if (!isControllerReady(mapController)) {
      return MapsConfig.defaultCameraPosition;
    }

    final controller = mapController as MapController;
    final camera = controller.camera;

    return MapCameraPosition(
      target: MapLatLng(camera.center.latitude, camera.center.longitude),
      zoom: camera.zoom,
      bearing: camera.rotation,
      tilt: 0.0, // flutter_map doesn't support tilt
    );
  }

  @override
  bool isControllerReady(dynamic mapController) {
    return mapController != null && mapController is MapController;
  }

  @override
  Future<void> dispose() async {
    _controllerMarkers.clear();
    _controllerCircles.clear();
    _createdControllers.clear();
    _updateCallbacks.clear();
    _isInitialized = false;
  }

  void _triggerMapUpdate(MapController controller) {
    final markerCount = _controllerMarkers[controller]?.length ?? 0;
    final circleCount = _controllerCircles[controller]?.length ?? 0;
    debugPrint('Map update triggered for controller - markers: $markerCount, circles: $circleCount');
    
    // Trigger the widget rebuild callback
    _updateCallbacks[controller]?.call();
  }

  (latlong.LatLng?, double?) _convertCameraUpdate(MapCameraUpdate update, MapController? controller) {
    if (update is NewLatLng) {
      return (
        latlong.LatLng(update.latLng.latitude, update.latLng.longitude),
        null
      );
    } else if (update is NewLatLngZoom) {
      return (
        latlong.LatLng(update.latLng.latitude, update.latLng.longitude),
        update.zoom
      );
    } else if (update is NewCameraPosition) {
      return (
        latlong.LatLng(
          update.position.target.latitude,
          update.position.target.longitude,
        ),
        update.position.zoom
      );
    } else if (update is ZoomIn) {
      final currentZoom = controller?.camera.zoom ?? MapsConfig.defaultZoom;
      return (null, currentZoom + 1.0);
    } else if (update is ZoomOut) {
      final currentZoom = controller?.camera.zoom ?? MapsConfig.defaultZoom;
      return (null, currentZoom - 1.0);
    } else if (update is ZoomTo) {
      return (null, update.zoom);
    }

    return (null, null);
  }
}
