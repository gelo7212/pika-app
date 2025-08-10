import 'package:flutter/foundation.dart';
import 'dart:async';
import 'maps/map_service_interface.dart';

/// Manages and caches map controllers to improve performance across platforms
/// This is a legacy service that's been replaced by the new MapService abstraction.
/// It's kept for backward compatibility but delegates to the new system.
class MapControllerManager {
  static MapControllerManager? _instance;
  static MapControllerManager get instance =>
      _instance ??= MapControllerManager._();
  MapControllerManager._();

  final Map<String, dynamic> _controllers = {};
  final Map<String, DateTime> _controllerTimestamps = {};
  final Map<String, Completer<dynamic>> _pendingControllers = {};

  static const Duration _controllerCacheTimeout = Duration(minutes: 30);
  Timer? _cleanupTimer;

  /// Initialize the manager
  void initialize() {
    // Start periodic cleanup of expired controllers
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredControllers();
    });

    debugPrint(
        'MapControllerManager initialized (using cross-platform abstraction)');
  }

  /// Get or create a map controller for a specific context
  /// @deprecated Use MapService.instance.createMapWidget instead
  Future<dynamic> getController({
    required String contextId,
    required Function(dynamic) onMapCreated,
    MapLatLng? initialLocation,
    double? initialZoom,
  }) async {
    try {
      debugPrint(
          'MapControllerManager.getController is deprecated. Use MapService instead.');

      // Check if we have a valid cached controller
      if (_controllers.containsKey(contextId)) {
        final controller = _controllers[contextId]!;
        final timestamp = _controllerTimestamps[contextId]!;

        if (DateTime.now().difference(timestamp) < _controllerCacheTimeout) {
          debugPrint('Using cached map controller for $contextId');
          return controller;
        } else {
          // Controller expired, remove it
          await _removeController(contextId);
        }
      }

      // Check if controller creation is already in progress
      if (_pendingControllers.containsKey(contextId)) {
        debugPrint('Waiting for pending controller creation for $contextId');
        return await _pendingControllers[contextId]!.future;
      }

      // Create new controller
      final completer = Completer<dynamic>();
      _pendingControllers[contextId] = completer;

      debugPrint('Creating new map controller for $contextId');

      // The actual controller will be set when onMapCreated is called
      // We return null here and the caller should handle controller creation
      // through the normal MapService widget lifecycle

      return null;
    } catch (e) {
      debugPrint('Error getting map controller for $contextId: $e');
      _pendingControllers.remove(contextId);
      return null;
    }
  }

  /// Register a newly created controller
  /// @deprecated Controllers are now managed internally by MapService
  void registerController(String contextId, dynamic controller) {
    try {
      _controllers[contextId] = controller;
      _controllerTimestamps[contextId] = DateTime.now();

      // Complete pending controller if exists
      if (_pendingControllers.containsKey(contextId)) {
        _pendingControllers[contextId]!.complete(controller);
        _pendingControllers.remove(contextId);
      }

      debugPrint('Registered map controller for $contextId (legacy)');
    } catch (e) {
      debugPrint('Error registering controller for $contextId: $e');
    }
  }

  /// Update controller timestamp to extend its cache lifetime
  /// @deprecated Controllers are now managed internally by MapService
  void refreshController(String contextId) {
    if (_controllers.containsKey(contextId)) {
      _controllerTimestamps[contextId] = DateTime.now();
      debugPrint('Refreshed controller timestamp for $contextId (legacy)');
    }
  }

  /// Remove a specific controller from cache
  /// @deprecated Controllers are now managed internally by MapService
  Future<void> removeController(String contextId) async {
    await _removeController(contextId);
  }

  /// Internal method to remove controller
  Future<void> _removeController(String contextId) async {
    try {
      final controller = _controllers.remove(contextId);
      _controllerTimestamps.remove(contextId);

      if (controller != null) {
        debugPrint('Removed map controller for $contextId (legacy)');
      }
    } catch (e) {
      debugPrint('Error removing controller for $contextId: $e');
    }
  }

  /// Clean up expired controllers
  void _cleanupExpiredControllers() {
    try {
      final now = DateTime.now();
      final expiredContexts = <String>[];

      for (final entry in _controllerTimestamps.entries) {
        if (now.difference(entry.value) > _controllerCacheTimeout) {
          expiredContexts.add(entry.key);
        }
      }

      for (final contextId in expiredContexts) {
        _removeController(contextId);
      }

      if (expiredContexts.isNotEmpty) {
        debugPrint(
            'Cleaned up ${expiredContexts.length} expired map controllers (legacy)');
      }
    } catch (e) {
      debugPrint('Error during controller cleanup: $e');
    }
  }

  /// Get statistics about cached controllers
  Map<String, dynamic> getStats() {
    return {
      'active_controllers': _controllers.length,
      'pending_controllers': _pendingControllers.length,
      'oldest_controller_age': _getOldestControllerAge(),
      'note':
          'This is a legacy service. Use MapService for new implementations.',
    };
  }

  Duration? _getOldestControllerAge() {
    if (_controllerTimestamps.isEmpty) return null;

    final now = DateTime.now();
    final oldestTimestamp =
        _controllerTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b);

    return now.difference(oldestTimestamp);
  }

  /// Clear all cached controllers
  Future<void> clearAll() async {
    try {
      final contextIds = _controllers.keys.toList();
      for (final contextId in contextIds) {
        await _removeController(contextId);
      }

      _pendingControllers.clear();

      debugPrint('Cleared all map controllers (legacy)');
    } catch (e) {
      debugPrint('Error clearing all controllers: $e');
    }
  }

  /// Dispose the manager and clean up resources
  Future<void> dispose() async {
    try {
      _cleanupTimer?.cancel();
      await clearAll();
      debugPrint('MapControllerManager disposed (legacy)');
    } catch (e) {
      debugPrint('Error disposing MapControllerManager: $e');
    }
  }
}

/// Extension to provide controller context generation
/// @deprecated Use MapService abstraction instead
extension MapControllerContext on Object {
  String get mapControllerContextId {
    return '${runtimeType.toString()}_${hashCode}';
  }
}
