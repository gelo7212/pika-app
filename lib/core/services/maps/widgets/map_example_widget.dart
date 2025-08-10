import 'package:flutter/material.dart';
import '../map_service.dart';
import '../map_service_interface.dart';

/// Example widget demonstrating the cross-platform map abstraction
class MapExampleWidget extends StatefulWidget {
  const MapExampleWidget({super.key});

  @override
  State<MapExampleWidget> createState() => _MapExampleWidgetState();
}

class _MapExampleWidgetState extends State<MapExampleWidget> {
  dynamic _mapController;
  bool _isMapReady = false;
  final List<MapMarker> _markers = [];

  @override
  void initState() {
    super.initState();
    _initializeMapService();
  }

  Future<void> _initializeMapService() async {
    try {
      await MapService.instance.initialize();
      debugPrint('Map service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize map service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Cross-Platform Map (${MapService.instance.currentPlatform})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: _isMapReady ? _addRandomMarker : null,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _isMapReady ? _clearMarkers : null,
          ),
        ],
      ),
      body: _buildMapWidget(),
      floatingActionButton: _isMapReady
          ? FloatingActionButton(
              onPressed: _moveToManila,
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _buildMapWidget() {
    return MapService.instance.createMapWidget(
      initialCameraPosition: MapService.defaultCameraPosition,
      onMapCreated: _onMapCreated,
      onMapTap: _onMapTap,
      onMapLongPress: _onMapLongPress,
      myLocationEnabled: true,
      style: MapStyle.street,
    );
  }

  void _onMapCreated(dynamic controller) {
    setState(() {
      _mapController = controller;
      _isMapReady = MapService.instance.isControllerReady(controller);
    });
    debugPrint('Map created and ready: $_isMapReady');
  }

  void _onMapTap(MapLatLng location) {
    debugPrint('Map tapped at: ${location.latitude}, ${location.longitude}');

    // Show coordinates in a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tapped: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onMapLongPress(MapLatLng location) {
    debugPrint(
        'Map long pressed at: ${location.latitude}, ${location.longitude}');
    _addMarkerAtLocation(location);
  }

  Future<void> _addMarkerAtLocation(MapLatLng location) async {
    if (!_isMapReady) return;

    final markerId = 'marker_${DateTime.now().millisecondsSinceEpoch}';
    final marker = MapService.createMarker(
      id: markerId,
      position: location,
      title: 'Custom Marker',
      snippet: 'Added by long press',
    );

    try {
      await MapService.instance.addMarker(_mapController, marker);
      setState(() {
        _markers.add(marker);
      });
      debugPrint('Added marker at: $location');
    } catch (e) {
      debugPrint('Failed to add marker: $e');
    }
  }

  Future<void> _addRandomMarker() async {
    if (!_isMapReady) return;

    // Add a marker near Manila with some random offset
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    final latitude = 14.5995 + (random - 500) / 100000; // Small random offset
    final longitude = 120.9842 + (random - 500) / 100000;

    final location = MapLatLng(latitude, longitude);
    await _addMarkerAtLocation(location);
  }

  Future<void> _clearMarkers() async {
    if (!_isMapReady) return;

    try {
      for (final marker in _markers) {
        await MapService.instance.removeMarker(_mapController, marker.markerId);
      }
      setState(() {
        _markers.clear();
      });
      debugPrint('Cleared all markers');
    } catch (e) {
      debugPrint('Failed to clear markers: $e');
    }
  }

  Future<void> _moveToManila() async {
    if (!_isMapReady) return;

    try {
      final cameraUpdate = MapService.moveToLocation(
        const MapLatLng(14.5995, 120.9842), // Manila coordinates
        zoom: 16.0,
      );

      await MapService.instance.animateCamera(_mapController, cameraUpdate);
      debugPrint('Moved camera to Manila');
    } catch (e) {
      debugPrint('Failed to move camera: $e');
    }
  }

  @override
  void dispose() {
    // Dispose map service if needed
    super.dispose();
  }
}
