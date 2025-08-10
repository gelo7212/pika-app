import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import '../../../core/models/address_model.dart';
import '../../../core/services/maps/maps.dart';
import '../../../core/services/map_cache_service.dart';
import '../../../core/services/cached_geocoding_service.dart';

class AddAddressDialogNew extends StatefulWidget {
  final Address? address; // null for new address, non-null for editing
  final Function(String name, String address, String phone, double latitude,
      double longitude) onSave;

  const AddAddressDialogNew({
    super.key,
    this.address,
    required this.onSave,
  });

  @override
  State<AddAddressDialogNew> createState() => _AddAddressDialogNewState();
}

class _AddAddressDialogNewState extends State<AddAddressDialogNew> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  dynamic _mapController;
  final Location _location = Location();

  MapLatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  bool _isReverseGeocoding = false;
  String? _locationError;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeMapService();
    _initializeFields();

    // Only get current location if we're adding a new address (not editing)
    if (widget.address == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
      });
    }
  }

  Future<void> _initializeMapService() async {
    try {
      await MapService.instance.initialize();
      debugPrint('Map service initialized in AddAddressDialog');
    } catch (e) {
      debugPrint('Failed to initialize map service: $e');
    }
  }

  void _initializeFields() {
    if (widget.address != null) {
      _nameController.text = widget.address!.name;
      _addressController.text = widget.address!.address;
      _phoneController.text = widget.address!.phone;
      _selectedLocation = MapLatLng(
        widget.address!.latitude,
        widget.address!.longitude,
      );

      // Schedule marker addition after widget build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleMarkerAddition();
      });
    }
  }

  void _scheduleMarkerAddition() {
    // Try to add marker with retries if map controller isn't ready
    Future.delayed(const Duration(milliseconds: 1000), () async {
      int retries = 0;
      const maxRetries = 5; // Reduced from 15 to 5
      const retryDelay = Duration(milliseconds: 1000); // Increased delay

      while (!_isMapReady && retries < maxRetries && mounted) {
        await Future.delayed(retryDelay);
        retries++;
        debugPrint('Waiting for map controller... retry $retries/$maxRetries');
      }

      if (_isMapReady && _selectedLocation != null && mounted) {
        await _addMarker(_selectedLocation!);
      } else {
        debugPrint(
            'Map not ready after $maxRetries retries, continuing without marker');
        // Don't show this as an error since the location is still saved
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    debugPrint('Starting current location request...');

    try {
      // Check for cached current location first
      final cachedLocation =
          await MapCacheService.instance.getCachedCurrentLocation();
      if (cachedLocation != null && widget.address == null) {
        setState(() {
          _selectedLocation =
              MapLatLng(cachedLocation.latitude, cachedLocation.longitude);
        });
        await _addMarker(_selectedLocation!);
        await _reverseGeocode(
            cachedLocation.latitude, cachedLocation.longitude);
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      // Check location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permissions denied');
        }
      }

      // Get current location with timeout
      final locationData = await _location.getLocation().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Location request timeout'),
          );

      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng =
            MapLatLng(locationData.latitude!, locationData.longitude!);

        setState(() {
          _selectedLocation = latLng;
        });

        // Cache the location
        await MapCacheService.instance.cacheCurrentLocation(latLng);

        await _addMarker(latLng);
        await _reverseGeocode(latLng.latitude, latLng.longitude);

        // Move camera to current location
        if (_isMapReady) {
          final cameraUpdate = MapService.moveToLocation(latLng, zoom: 16.0);
          await MapService.instance.animateCamera(_mapController, cameraUpdate);
        }
      } else {
        throw Exception('Unable to get location coordinates');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _addMarker(MapLatLng location) async {
    if (!_isMapReady) {
      debugPrint('Map controller not available for adding marker');
      return;
    }

    try {
      // Remove existing marker first (if any)
      await MapService.instance.removeMarker(_mapController, 'address_marker');

      // Add new marker
      final marker = MapService.createMarker(
        id: 'address_marker',
        position: location,
        title: 'Selected Location',
        snippet: 'Tap to confirm this location',
      );

      await MapService.instance.addMarker(_mapController, marker);
      debugPrint(
          'Marker added successfully at: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      debugPrint('Error adding marker: $e');
      // Continue without marker - the location is still selected and stored
      debugPrint('Continuing without visual marker - location is still saved');
    }
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    if (!mounted) return;

    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      debugPrint(
          'Starting cached reverse geocoding for: $latitude, $longitude');

      // Validate coordinates before proceeding
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw Exception('Invalid coordinates');
      }

      // Use cached geocoding service
      final address = await CachedGeocodingService.instance.reverseGeocode(
        latitude,
        longitude,
      );

      if (address != null && address.isNotEmpty && mounted) {
        setState(() {
          _addressController.text = address;
        });
        debugPrint(
            'Address updated successfully with cached geocoding service');
      } else {
        _setCoordinateFallback(latitude, longitude);
      }
    } catch (e) {
      debugPrint('Cached reverse geocoding failed: ${e.toString()}');
      if (mounted) {
        _setCoordinateFallback(latitude, longitude);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
        });
      }
    }
  }

  void _setCoordinateFallback(double latitude, double longitude) {
    if (mounted) {
      setState(() {
        _addressController.text =
            'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      });
      debugPrint('Set coordinate fallback address');
    }
  }

  Widget _buildMapWidget() {
    return MapService.instance.createMapWidget(
      initialCameraPosition: _selectedLocation != null
          ? MapCameraPosition(target: _selectedLocation!, zoom: 16.0)
          : MapService.defaultCameraPosition,
      onMapCreated: (controller) {
        debugPrint('Map controller received in AddAddressDialog');
        setState(() {
          _mapController = controller;
          _isMapReady = MapService.instance.isControllerReady(controller);
        });
        debugPrint('Map created and ready: $_isMapReady');

        // If we already have a selected location and the map is ready, add the marker
        if (_isMapReady && _selectedLocation != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _addMarker(_selectedLocation!);
            }
          });
        }
      },
      onMapTap: (location) async {
        debugPrint(
            'Map tapped at: ${location.latitude}, ${location.longitude}');

        setState(() {
          _selectedLocation = location;
        });

        await _addMarker(location);
        await _reverseGeocode(location.latitude, location.longitude);
      },
      myLocationEnabled: true,
      style: MapStyle.street,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.address == null ? 'Add New Address' : 'Edit Address',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Map section
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      _buildMapWidget(),
                      if (_isLoadingLocation)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_locationError != null)
                        Container(
                          color: Colors.red.withOpacity(0.1),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(height: 8),
                                Text(
                                  'Location Error',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    _locationError!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Form section
            Expanded(
              flex: 2,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Address Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an address name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                border: const OutlineInputBorder(),
                                suffixIcon: _isReverseGeocoding
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : null,
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _selectedLocation != null ? _saveAddress : null,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAddress() {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      widget.onSave(
        _nameController.text,
        _addressController.text,
        _phoneController.text,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
