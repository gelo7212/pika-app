class DeliveryStatusResponse {
  final String orderId;
  final DriverDetails? driverDetails;
  final String status;
  final bool isPaid;

  const DeliveryStatusResponse({
    required this.orderId,
    this.driverDetails,
    required this.status,
    required this.isPaid,
  });

  factory DeliveryStatusResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryStatusResponse(
      orderId: json['orderId'] ?? '',
      driverDetails: json['driverDetails'] != null
          ? DriverDetails.fromJson(json['driverDetails'])
          : null,
      status: json['status'] ?? '',
      isPaid: json['isPaid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'driverDetails': driverDetails?.toJson(),
      'status': status,
      'isPaid': isPaid,
    };
  }
}

class DriverDetails {
  final String driverId;
  final String name;
  final String phone;
  final String plateNumber;
  final String photo;

  const DriverDetails({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.plateNumber,
    required this.photo,
  });

  factory DriverDetails.fromJson(Map<String, dynamic> json) {
    return DriverDetails(
      driverId: json['driverId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      photo: json['photo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'name': name,
      'phone': phone,
      'plateNumber': plateNumber,
      'photo': photo,
    };
  }
}

enum OrderStatus {
  cart,
  pending,
  confirmed,
  preparing,
  readyForPickup,
  inProgress,
  completed,
  canceled,
}

enum MonitoringStatus {
  onCart('On Cart'),
  new_('New'),
  preparing('Preparing'),
  cooking('Cooking'),
  packing('Packing'),
  ready('Ready'),
  canceled('Canceled'),
  completed('Completed'),
  delivered('Delivered'),
  onTheWay('On the Way'),
  pickedUp('Picked Up'),
  arrived('Arrived'),
  returned('Returned'),
  assigningDriver('Assigning Driver'),
  driverAssigned('Driver Assigned');

  const MonitoringStatus(this.value);
  final String value;
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.cart:
        return 'Order On Cart';
      case OrderStatus.pending:
        return 'Order Pending';
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.inProgress:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Delivered';
      case OrderStatus.canceled:
        return 'Canceled';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.cart:
        return 'Your have items in your cart, please complete your order.';
      case OrderStatus.pending:
        return 'Your order is being processed';
      case OrderStatus.confirmed:
        return 'Your order has been confirmed';
      case OrderStatus.preparing:
        return 'Your order is being prepared';
      case OrderStatus.readyForPickup:
        return 'Your order is ready for pickup';
      case OrderStatus.inProgress:
        return 'Your order is on the way';
      case OrderStatus.completed:
        return 'Your order has been delivered';
      case OrderStatus.canceled:
        return 'Your order has been canceled';
    }
  }
}

extension MonitoringStatusExtension on MonitoringStatus {
  String get displayName {
    return value;
  }
}

// Helper function to parse MonitoringStatus from backend string
MonitoringStatus parseMonitoringStatus(String status) {
  for (MonitoringStatus monitoringStatus in MonitoringStatus.values) {
    if (monitoringStatus.value == status) {
      return monitoringStatus;
    }
  }
  // Default fallback
  return MonitoringStatus.preparing;
}

// Helper function to derive OrderStatus from MonitoringStatus
OrderStatus getOrderStatusFromMonitoring(MonitoringStatus monitoringStatus) {
  switch (monitoringStatus) {
    case MonitoringStatus.onCart:
      return OrderStatus.cart;
    case MonitoringStatus.new_:
      return OrderStatus.confirmed;
    case MonitoringStatus.preparing:
      return OrderStatus.preparing;
    case MonitoringStatus.cooking:
      return OrderStatus.preparing;
    case MonitoringStatus.packing:
      return OrderStatus.preparing;
    case MonitoringStatus.ready:
      return OrderStatus.readyForPickup;
    case MonitoringStatus.assigningDriver:
      return OrderStatus.readyForPickup;
    case MonitoringStatus.driverAssigned:
      return OrderStatus.readyForPickup;
    case MonitoringStatus.pickedUp:
      return OrderStatus.inProgress;
    case MonitoringStatus.onTheWay:
      return OrderStatus.inProgress;
    case MonitoringStatus.arrived:
      return OrderStatus.inProgress;
    case MonitoringStatus.completed:
      return OrderStatus.completed;
    case MonitoringStatus.delivered:
      return OrderStatus.completed;
    case MonitoringStatus.canceled:
      return OrderStatus.canceled;
    case MonitoringStatus.returned:
      return OrderStatus.canceled;
  }
}
