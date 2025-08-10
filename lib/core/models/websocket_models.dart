// WebSocket Event Models
class DeliveryUpdateEvent {
  final String orderId;
  final String status;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  DeliveryUpdateEvent({
    required this.orderId,
    required this.status,
    required this.timestamp,
    this.metadata,
  });

  factory DeliveryUpdateEvent.fromJson(Map<String, dynamic> json) {
    return DeliveryUpdateEvent(
      orderId: json['orderId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class PaymentUpdateEvent {
  final String orderId;
  final String paymentStatus;
  final String? transactionId;
  final double? amount;
  final DateTime timestamp;

  PaymentUpdateEvent({
    required this.orderId,
    required this.paymentStatus,
    this.transactionId,
    this.amount,
    required this.timestamp,
  });

  factory PaymentUpdateEvent.fromJson(Map<String, dynamic> json) {
    return PaymentUpdateEvent(
      orderId: json['orderId']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? json['status']?.toString() ?? '',
      transactionId: json['transactionId']?.toString(),
      amount: (json['amount'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'paymentStatus': paymentStatus,
      if (transactionId != null) 'transactionId': transactionId,
      if (amount != null) 'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class NotificationEvent {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  NotificationEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.data,
  });

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      if (data != null) 'data': data,
    };
  }
}

// Connection status enum
enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

// WebSocket event types
class WebSocketEventTypes {
  // User events
  static const String joinUser = 'join-user';
  
  // Delivery events
  static const String deliveryUpdate = 'delivery:update';
  static const String deliveryAssigningDriver = 'delivery:assigning_driver';
  static const String deliveryDriverAssigned = 'delivery:driver_assigned';
  static const String deliveryReadyForPickup = 'delivery:ready_for_pickup';
  static const String deliveryPickedUp = 'delivery:picked_up';
  static const String deliveryOnTheWay = 'delivery:on_the_way';
  static const String deliveryDelivered = 'delivery:delivered';
  static const String deliveryFailed = 'delivery:failed';
  static const String deliveryReturned = 'delivery:returned';
  
  // Payment events
  static const String paymentSuccess = 'payment:success';
  static const String paymentFailed = 'payment:failed';
  static const String paymentUpdate = 'payment:update';
  
  // General notifications
  static const String notification = 'notification';
  
  // Connection events
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String reconnect = 'reconnect';
  static const String reconnectError = 'reconnect_error';
}
