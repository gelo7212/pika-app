import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/websocket_service_interface.dart';
import '../models/websocket_models.dart';
import '../di/service_locator.dart';

// WebSocket service provider
final webSocketServiceProvider = Provider<WebSocketServiceInterface>((ref) {
  return serviceLocator<WebSocketServiceInterface>();
});

// Connection status provider
final connectionStatusProvider = StreamProvider<WebSocketConnectionStatus>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.connectionStatusStream;
});

// Connection state provider (boolean for easier usage)
final isConnectedProvider = Provider<bool>((ref) {
  final connectionStatus = ref.watch(connectionStatusProvider);
  return connectionStatus.when(
    data: (status) => status == WebSocketConnectionStatus.connected,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Delivery updates provider
final deliveryUpdatesProvider = StreamProvider<DeliveryUpdateEvent>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.deliveryUpdates;
});

// Payment updates provider
final paymentUpdatesProvider = StreamProvider<PaymentUpdateEvent>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.paymentUpdates;
});

// Notifications provider
final notificationsProvider = StreamProvider<NotificationEvent>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.notifications;
});

// WebSocket errors provider
final webSocketErrorsProvider = StreamProvider<String>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.errors;
});

// Provider for managing WebSocket connection lifecycle
final webSocketManagerProvider = Provider((ref) {
  return WebSocketManager(ref);
});

class WebSocketManager {
  final ProviderRef _ref;
  String? _currentUserId;

  WebSocketManager(this._ref);

  Future<void> connectUser(String userId) async {
    final webSocketService = _ref.read(webSocketServiceProvider);
    _currentUserId = userId;
    
    try {
      await webSocketService.connect(userId);
    } catch (e) {
      // Handle connection error
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final webSocketService = _ref.read(webSocketServiceProvider);
    await webSocketService.disconnect();
    _currentUserId = null;
  }

  void joinUserRoom(String userId) {
    final webSocketService = _ref.read(webSocketServiceProvider);
    webSocketService.joinUser(userId);
  }

  void leaveUserRoom(String userId) {
    final webSocketService = _ref.read(webSocketServiceProvider);
    webSocketService.leaveUser(userId);
  }

  String? get currentUserId => _currentUserId;
}
