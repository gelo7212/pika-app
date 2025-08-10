import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/websocket_service_interface.dart';
import '../interfaces/auth_interface.dart';
import '../di/service_locator.dart';
import '../models/websocket_models.dart';
import '../providers/auth_provider.dart';

class WebSocketConnectionManager {
  final WebSocketServiceInterface _webSocketService;
  final AuthInterface _authService;
  bool _isInitialized = false;
  String? _currentUserId;

  WebSocketConnectionManager({
    required WebSocketServiceInterface webSocketService,
    required AuthInterface authService,
  })  : _webSocketService = webSocketService,
        _authService = authService;

  /// Initialize the WebSocket connection manager
  /// This should be called after user authentication
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if user is authenticated
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        await _connectAuthenticatedUser();
      }

      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize WebSocket connection manager: $e');
    }
  }

  /// Connect for an authenticated user
  Future<void> connectAuthenticatedUser() async {
    await _connectAuthenticatedUser();
  }

  /// Connect for a specific user ID
  Future<void> connectUser(String userId) async {
    try {
      await _webSocketService.connect(userId);
      _currentUserId = userId;
    } catch (e) {
      print('Failed to connect WebSocket for user $userId: $e');
      rethrow;
    }
  }

  /// Disconnect the WebSocket
  Future<void> disconnect() async {
    try {
      await _webSocketService.disconnect();
      _currentUserId = null;
    } catch (e) {
      print('Failed to disconnect WebSocket: $e');
    }
  }

  /// Check if WebSocket is connected
  bool get isConnected => _webSocketService.isConnected;

  /// Get current connection status
  WebSocketConnectionStatus get connectionStatus => _webSocketService.connectionStatus;

  /// Get event streams
  Stream<DeliveryUpdateEvent> get deliveryUpdates => _webSocketService.deliveryUpdates;
  Stream<PaymentUpdateEvent> get paymentUpdates => _webSocketService.paymentUpdates;
  Stream<NotificationEvent> get notifications => _webSocketService.notifications;
  Stream<WebSocketConnectionStatus> get connectionStatusStream => _webSocketService.connectionStatusStream;
  Stream<String> get errors => _webSocketService.errors;

  String? get currentUserId => _currentUserId;

  Future<void> _connectAuthenticatedUser() async {
    try {
      final token = await _authService.getCurrentUserToken();
      if (token != null) {
        // Extract user ID from token
        final payload = await _authService.decodeToken(token);
        if (payload != null) {
          final userId = payload.sub; // Assuming 'sub' contains user ID
          await connectUser(userId);
        }
      }
    } catch (e) {
      print('Failed to connect authenticated user: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _webSocketService.dispose();
  }
}

// Provider for WebSocket connection manager
final webSocketConnectionManagerProvider = Provider<WebSocketConnectionManager>((ref) {
  return WebSocketConnectionManager(
    webSocketService: serviceLocator<WebSocketServiceInterface>(),
    authService: serviceLocator<AuthInterface>(),
  );
});

// Provider to automatically manage connection based on auth state
final autoWebSocketProvider = FutureProvider<void>((ref) async {
  final connectionManager = ref.watch(webSocketConnectionManagerProvider);
  final isLoggedIn = await ref.watch(isLoggedInProvider.future);

  if (isLoggedIn) {
    await connectionManager.initialize();
  } else {
    await connectionManager.disconnect();
  }
});

// Provider to listen for auth state changes and manage WebSocket accordingly
final webSocketAuthListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(isLoggedInProvider, (previous, next) {
    next.whenData((isLoggedIn) async {
      final connectionManager = ref.read(webSocketConnectionManagerProvider);
      
      if (isLoggedIn) {
        try {
          await connectionManager.connectAuthenticatedUser();
        } catch (e) {
          print('Failed to auto-connect WebSocket: $e');
        }
      } else {
        await connectionManager.disconnect();
      }
    });
  });
});
