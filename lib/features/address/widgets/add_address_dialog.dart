import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        // Use longer delay for web platform to ensure map is fully initialized
        final delayMs = kIsWeb ? 2000 : 1000;
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted) {
            _getCurrentLocation();
          }
        });
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
      
      // Format the existing phone number
      final phone = widget.address!.phone;
      _phoneController.text = _formatExistingPhoneNumber(phone);
      
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

  /// Format existing phone number to match the expected format
  String _formatExistingPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) return '';
    
    // If it starts with 63, format as +63 9XX XXX XXXX
    if (digitsOnly.startsWith('63') && digitsOnly.length >= 12) {
      final mobileNumber = digitsOnly.substring(2, 12); // Get 10 digits after 63
      return '+63 ${mobileNumber.substring(0, 1)}${mobileNumber.substring(1, 3)} ${mobileNumber.substring(3, 6)} ${mobileNumber.substring(6, 10)}';
    }
    
    // If it starts with 9 and has 10 digits, assume it's a local mobile number
    if (digitsOnly.startsWith('9') && digitsOnly.length >= 10) {
      final mobileNumber = digitsOnly.substring(0, 10);
      return '+63 ${mobileNumber.substring(0, 1)}${mobileNumber.substring(1, 3)} ${mobileNumber.substring(3, 6)} ${mobileNumber.substring(6, 10)}';
    }
    
    // For other formats, try to format as best as possible
    if (digitsOnly.length >= 10) {
      final last10 = digitsOnly.substring(digitsOnly.length - 10);
      if (last10.startsWith('9')) {
        return '+63 ${last10.substring(0, 1)}${last10.substring(1, 3)} ${last10.substring(3, 6)} ${last10.substring(6, 10)}';
      }
    }
    
    // If we can't format it properly, return the original with +63 prefix if it doesn't have it
    return digitsOnly.startsWith('63') ? '+$digitsOnly' : '+63$digitsOnly';
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
        await _moveCameraToLocation(_selectedLocation!);
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
        await _moveCameraToLocation(_selectedLocation!);
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

      // Handle location permissions differently for web and mobile
      if (kIsWeb) {
        // For web, try to get location directly and handle permission errors gracefully
        try {
          final locationData = await _location.getLocation().timeout(
            const Duration(seconds: 15), // Reduced timeout for web
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
            await _moveCameraToLocation(latLng);
          } else {
            throw Exception('Unable to get location coordinates');
          }
        } catch (e) {
          // On web, geolocation API might not be available or permission denied
          debugPrint('Web geolocation error: $e');
          
          // For web, fallback to Manila, Philippines as default location for better UX
          final defaultLocation = const MapLatLng(14.5995, 120.9842); // Manila coordinates
          setState(() {
            _selectedLocation = defaultLocation;
            _locationError = 'Location access not available. Map centered on Manila. Please tap on the map to select your location.';
          });
          
          await _addMarker(defaultLocation);
          await _moveCameraToLocation(defaultLocation);
          // Don't rethrow the error - just continue with default location
        }
      } else {
        // For mobile, use the standard permission flow
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
          await _moveCameraToLocation(latLng);
        } else {
          throw Exception('Unable to get location coordinates');
        }
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

  Future<void> _moveCameraToLocation(MapLatLng location) async {
    // Wait for map to be ready with retry logic
    int retries = 0;
    const maxRetries = 10;
    const retryDelay = Duration(milliseconds: 500);

    while (!_isMapReady && retries < maxRetries && mounted) {
      await Future.delayed(retryDelay);
      retries++;
      debugPrint('Waiting for map to be ready for camera movement... retry $retries/$maxRetries');
    }

    if (_isMapReady && _mapController != null && mounted) {
      try {
        final cameraUpdate = MapService.moveToLocation(location, zoom: 16.0);
        await MapService.instance.animateCamera(_mapController, cameraUpdate);
        debugPrint('Camera moved to location: ${location.latitude}, ${location.longitude}');
      } catch (e) {
        debugPrint('Error moving camera to location: $e');
        // Try with moveCamera instead of animateCamera as fallback
        try {
          final cameraUpdate = MapService.moveToLocation(location, zoom: 16.0);
          await MapService.instance.moveCamera(_mapController, cameraUpdate);
          debugPrint('Camera moved (non-animated) to location: ${location.latitude}, ${location.longitude}');
        } catch (e2) {
          debugPrint('Error with fallback camera movement: $e2');
        }
      }
    } else {
      debugPrint('Map not ready for camera movement after $maxRetries retries');
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
        
        // Only update state if the controller has actually changed
        if (_mapController != controller) {
          _mapController = controller;
          final isReady = MapService.instance.isControllerReady(controller);
          
          if (_isMapReady != isReady) {
            setState(() {
              _isMapReady = isReady;
            });
            debugPrint('Map created and ready: $_isMapReady');

            // If we already have a selected location and the map is ready, add the marker and move camera
            if (_isMapReady && _selectedLocation != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _addMarker(_selectedLocation!);
                  _moveCameraToLocation(_selectedLocation!);
                }
              });
            } else if (_isMapReady && widget.address == null) {
              // For new addresses, try to get current location again if it hasn't been set
              // This handles cases where location request completed before map was ready
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _selectedLocation == null && !_isLoadingLocation) {
                  debugPrint('Map ready but no location set - retrying location request');
                  _getCurrentLocation();
                }
              });
            }
          }
        } else {
          debugPrint('Map controller unchanged, skipping state update');
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
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _PhilippinePhoneNumberFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+63 9XX XXX XXXX',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.phone),
                                helperText: 'Format: +63 followed by 10 digits',
                                helperStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                
                                // Remove all non-digit characters for validation
                                final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                                
                                // Check if it starts with 63 and has 12 digits total (63 + 10 digits)
                                if (!digitsOnly.startsWith('63')) {
                                  return 'Phone number must start with +63';
                                }
                                
                                if (digitsOnly.length != 12) {
                                  return 'Phone number must have 10 digits after +63';
                                }
                                
                                // Check if the first digit after 63 is 9 (mobile number)
                                if (digitsOnly[2] != '9') {
                                  return 'Mobile number must start with 9 after +63';
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
      // Clean the phone number (remove formatting) before saving
      final cleanedPhone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      
      widget.onSave(
        _nameController.text,
        _addressController.text,
        '+$cleanedPhone', // Save with + prefix for international format
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

/// Custom text input formatter for Philippine phone numbers
/// Formats input as +63 9XX XXX XXXX
class _PhilippinePhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Get only digits from the new value
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // If empty, return empty
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    String formatted = '';
    int selectionIndex = newValue.selection.end;
    
    // Always start with +63
    if (digitsOnly.startsWith('63')) {
      // Input already has 63, use it
      formatted = '+63';
      final remainingDigits = digitsOnly.substring(2);
      
      // Format the remaining digits (up to 10 digits for mobile)
      if (remainingDigits.isNotEmpty) {
        formatted += ' ';
        if (remainingDigits.length >= 1) {
          formatted += remainingDigits.substring(0, 1);
        }
        if (remainingDigits.length >= 2) {
          formatted += remainingDigits.substring(1, remainingDigits.length >= 3 ? 3 : remainingDigits.length);
        }
        if (remainingDigits.length >= 4) {
          formatted += ' ${remainingDigits.substring(3, remainingDigits.length >= 6 ? 6 : remainingDigits.length)}';
        }
        if (remainingDigits.length >= 7) {
          formatted += ' ${remainingDigits.substring(6, remainingDigits.length >= 10 ? 10 : remainingDigits.length)}';
        }
      }
    } else {
      // Input doesn't start with 63, assume user is entering local number starting with 9
      formatted = '+63';
      if (digitsOnly.isNotEmpty) {
        formatted += ' ';
        // Take up to 10 digits for the mobile number
        final mobileDigits = digitsOnly.substring(0, digitsOnly.length >= 10 ? 10 : digitsOnly.length);
        
        if (mobileDigits.length >= 1) {
          formatted += mobileDigits.substring(0, 1);
        }
        if (mobileDigits.length >= 2) {
          formatted += mobileDigits.substring(1, mobileDigits.length >= 3 ? 3 : mobileDigits.length);
        }
        if (mobileDigits.length >= 4) {
          formatted += ' ${mobileDigits.substring(3, mobileDigits.length >= 6 ? 6 : mobileDigits.length)}';
        }
        if (mobileDigits.length >= 7) {
          formatted += ' ${mobileDigits.substring(6, mobileDigits.length >= 10 ? 10 : mobileDigits.length)}';
        }
      }
    }
    
    // Limit the total length (should not exceed +63 9XX XXX XXXX = 17 characters)
    if (formatted.length > 17) {
      formatted = formatted.substring(0, 17);
    }
    
    // Calculate new cursor position
    int newSelectionIndex = formatted.length;
    if (selectionIndex <= newValue.text.length) {
      // Try to maintain relative cursor position
      final oldDigitsCount = oldValue.text.replaceAll(RegExp(r'[^\d]'), '').length;
      final newDigitsCount = digitsOnly.length;
      
      if (newDigitsCount > oldDigitsCount) {
        // Digits were added, place cursor at end
        newSelectionIndex = formatted.length;
      } else if (newDigitsCount < oldDigitsCount) {
        // Digits were removed, adjust cursor position
        newSelectionIndex = formatted.length;
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }
}
