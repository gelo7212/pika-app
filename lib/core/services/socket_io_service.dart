import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../interfaces/websocket_service_interface.dart';
import '../models/websocket_models.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class SocketIOService implements WebSocketServiceInterface {
  late io.Socket _socket;

  // Stream controllers for events
  final _deliveryUpdatesController =
      StreamController<DeliveryUpdateEvent>.broadcast();
  final _paymentUpdatesController =
      StreamController<PaymentUpdateEvent>.broadcast();
  final _notificationsController =
      StreamController<NotificationEvent>.broadcast();
  final _connectionStatusController =
      StreamController<WebSocketConnectionStatus>.broadcast();
  final _errorsController = StreamController<String>.broadcast();

  // Connection status
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;
  String? _currentUserId;

  // Configuration
  static const String _socketUrl =
      ApiConfig.webSocketUrl ?? 'http://localhost:3090'; // WebSocket server URL
  static const Duration _reconnectDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  @override
  WebSocketConnectionStatus get connectionStatus => _connectionStatus;

  @override
  bool get isConnected =>
      _connectionStatus == WebSocketConnectionStatus.connected;

  @override
  Stream<DeliveryUpdateEvent> get deliveryUpdates =>
      _deliveryUpdatesController.stream;

  @override
  Stream<PaymentUpdateEvent> get paymentUpdates =>
      _paymentUpdatesController.stream;

  @override
  Stream<NotificationEvent> get notifications =>
      _notificationsController.stream;

  @override
  Stream<WebSocketConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  /// Get authentication headers for WebSocket connection
  /// Includes: Authorization Bearer token, x-client-id, x-api-key, x-hashed-data
  Future<Map<String, String>> _getHeaders() async {
    final tokenService = serviceLocator<TokenServiceInterface>();
    final tokens = await tokenService.getStoredTokens();

    if (tokens == null || tokens.userAccessToken.isEmpty) {
      throw Exception('No authentication token available');
    }

    return {
      ...ApiConfig.getDefaultHeaders(),
      'Authorization': 'Bearer ${tokens.userAccessToken}',
    };
  }

  @override
  Future<void> connect(String userId) async {
    try {
      _currentUserId = userId;
      _updateConnectionStatus(WebSocketConnectionStatus.connecting);

      // Get authentication headers and token
      Map<String, String> authHeaders;
      String accessToken;
      try {
        authHeaders = await _getHeaders();
        final tokenService = serviceLocator<TokenServiceInterface>();
        final tokens = await tokenService.getStoredTokens();
        accessToken = tokens!.userAccessToken;
      } catch (e) {
        _updateConnectionStatus(WebSocketConnectionStatus.error);
        _errorsController.add('Authentication failed: $e');
        debugPrint('WebSocket authentication error: $e');
        rethrow;
      }

      // Configure socket options with authentication
      _socket = io.io(
          _socketUrl,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .enableReconnection()
              .setReconnectionDelay(_reconnectDelay.inMilliseconds)
              .setReconnectionAttempts(5)
              .setTimeout(_connectionTimeout.inMilliseconds)
              .setExtraHeaders({
                ...authHeaders,
                'authorization': 'Bearer $accessToken',
                'credentials': 'true',
              })
              .setAuth({
                'token': accessToken,
              })
              .build());

      _setupEventListeners();

      // Wait for connection or timeout
      final completer = Completer<void>();
      Timer? timeoutTimer;

      void onConnected() {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          completer.complete();
        }
      }

      void onError() {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          completer.completeError('Connection failed');
        }
      }

      _socket.once(WebSocketEventTypes.connect, (_) => onConnected());
      _socket.once(WebSocketEventTypes.connectError, (_) => onError());

      timeoutTimer = Timer(_connectionTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError('Connection timeout');
        }
      });

      _socket.connect();

      await completer.future;
    } catch (e) {
      _updateConnectionStatus(WebSocketConnectionStatus.error);
      _errorsController.add('Connection failed: $e');
      debugPrint('WebSocket connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_currentUserId != null) {
        leaveUser(_currentUserId!);
      }

      _socket.disconnect();
      _updateConnectionStatus(WebSocketConnectionStatus.disconnected);
      _currentUserId = null;

      debugPrint('WebSocket disconnected successfully');
    } catch (e) {
      _errorsController.add('Disconnect error: $e');
      debugPrint('WebSocket disconnect error: $e');
    }
  }

  void _setupEventListeners() {
    // Connection events
    _socket.on(WebSocketEventTypes.connect, (_) {
      debugPrint('WebSocket connected');
      _updateConnectionStatus(WebSocketConnectionStatus.connected);

      // Auto-join user on connection
      if (_currentUserId != null) {
        joinUser(_currentUserId!);
      }
    });

    _socket.on(WebSocketEventTypes.disconnect, (_) {
      debugPrint('WebSocket disconnected');
      _updateConnectionStatus(WebSocketConnectionStatus.disconnected);
    });

    _socket.on(WebSocketEventTypes.connectError, (data) {
      debugPrint('WebSocket connection error: $data');
      _updateConnectionStatus(WebSocketConnectionStatus.error);
      _errorsController.add('Connection error: $data');
    });

    _socket.on(WebSocketEventTypes.reconnect, (_) {
      debugPrint('WebSocket reconnected');
      _updateConnectionStatus(WebSocketConnectionStatus.connected);

      // Re-join user on reconnection
      if (_currentUserId != null) {
        joinUser(_currentUserId!);
      }
    });

    _socket.on(WebSocketEventTypes.reconnectError, (data) {
      debugPrint('WebSocket reconnection error: $data');
      _updateConnectionStatus(WebSocketConnectionStatus.reconnecting);
      _errorsController.add('Reconnection error: $data');
    });

    // Delivery events
    _socket.on(WebSocketEventTypes.deliveryUpdate, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryAssigningDriver, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryDriverAssigned, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryReadyForPickup, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryPickedUp, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryOnTheWay, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryDelivered, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryFailed, (data) {
      _handleDeliveryEvent(data);
    });

    _socket.on(WebSocketEventTypes.deliveryReturned, (data) {
      _handleDeliveryEvent(data);
    });

    // Payment events
    _socket.on(WebSocketEventTypes.paymentSuccess, (data) {
      _handlePaymentEvent(data);
    });

    _socket.on(WebSocketEventTypes.paymentFailed, (data) {
      _handlePaymentEvent(data);
    });

    _socket.on(WebSocketEventTypes.paymentUpdate, (data) {
      _handlePaymentEvent(data);
    });

    // General notifications
    _socket.on(WebSocketEventTypes.notification, (data) {
      _handleNotificationEvent(data);
    });
  }

  void _handleDeliveryEvent(dynamic data) {
    try {
      if (data == null) {
        debugPrint('Received null delivery data');
        return;
      }

      final eventData = data as Map<String, dynamic>;
      debugPrint('Raw delivery data: $eventData');

      final event = DeliveryUpdateEvent.fromJson(eventData);
      _deliveryUpdatesController.add(event);
      debugPrint(
          'Delivery update received: ${event.status} for order ${event.orderId}');
    } catch (e) {
      debugPrint('Error parsing delivery event: $e');
      debugPrint('Raw delivery data that caused error: $data');
      _errorsController.add('Error parsing delivery event: $e');
    }
  }

  void _handlePaymentEvent(dynamic data) {
    try {
      if (data == null) {
        debugPrint('Received null payment data');
        return;
      }

      final eventData = data as Map<String, dynamic>;
      debugPrint('Raw payment data: $eventData');

      final event = PaymentUpdateEvent.fromJson(eventData);
      _paymentUpdatesController.add(event);
      debugPrint(
          'Payment update received: ${event.paymentStatus} for order ${event.orderId}');
    } catch (e) {
      debugPrint('Error parsing payment event: $e');
      debugPrint('Raw payment data that caused error: $data');
      _errorsController.add('Error parsing payment event: $e');
    }
  }

  void _handleNotificationEvent(dynamic data) {
    try {
      if (data == null) {
        debugPrint('Received null notification data');
        return;
      }

      final eventData = data as Map<String, dynamic>;
      debugPrint('Raw notification data: $eventData');

      final event = NotificationEvent.fromJson(eventData);
      _notificationsController.add(event);
      debugPrint('Notification received: ${event.title}');
    } catch (e) {
      debugPrint('Error parsing notification event: $e');
      debugPrint('Raw notification data that caused error: $data');
      _errorsController.add('Error parsing notification event: $e');
    }
  }

  void _updateConnectionStatus(WebSocketConnectionStatus status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  @override
  void joinUser(String userId) {
    if (isConnected) {
      _socket.emit(WebSocketEventTypes.joinUser, userId);
      debugPrint('Joined user room: $userId');
    } else {
      debugPrint('Cannot join user room - not connected');
    }
  }

  @override
  void leaveUser(String userId) {
    if (isConnected) {
      _socket.emit('leave-user', userId);
      debugPrint('Left user room: $userId');
    }
  }

  @override
  void dispose() {
    try {
      disconnect();

      _deliveryUpdatesController.close();
      _paymentUpdatesController.close();
      _notificationsController.close();
      _connectionStatusController.close();
      _errorsController.close();

      debugPrint('WebSocket service disposed');
    } catch (e) {
      debugPrint('Error disposing WebSocket service: $e');
    }
  }
}
