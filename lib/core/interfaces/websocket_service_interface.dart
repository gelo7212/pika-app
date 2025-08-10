import '../models/websocket_models.dart';

abstract class WebSocketServiceInterface {
  // Connection management
  Future<void> connect(String userId);
  Future<void> disconnect();
  bool get isConnected;
  WebSocketConnectionStatus get connectionStatus;
  
  // Stream getters for listening to events
  Stream<DeliveryUpdateEvent> get deliveryUpdates;
  Stream<PaymentUpdateEvent> get paymentUpdates;
  Stream<NotificationEvent> get notifications;
  Stream<WebSocketConnectionStatus> get connectionStatusStream;
  
  // Event emitting
  void joinUser(String userId);
  void leaveUser(String userId);
  
  // Error handling
  Stream<String> get errors;
  
  // Cleanup
  void dispose();
}
