import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';
import '../di/service_locator.dart';
import '../models/delivery_status_model.dart';
import '../models/websocket_models.dart';
import 'websocket_provider.dart';

// Order service provider
final orderServiceProvider = Provider<OrderService>((ref) {
  return serviceLocator<OrderService>();
});

// Delivery service provider
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return serviceLocator<DeliveryService>();
});

// Recent pending order provider
final recentPendingOrderProvider = FutureProvider<OrderResponse?>((ref) async {
  final orderService = ref.watch(orderServiceProvider);
  
  try {
    return await orderService.getRecentPendingOrder();
  } catch (e) {
    // Return null if no pending orders or error
    return null;
  }
});

// Recent pending order with refresh capability
final recentPendingOrderWithRefreshProvider = FutureProvider.autoDispose<OrderResponse?>((ref) async {
  final orderService = ref.watch(orderServiceProvider);
  
  try {
    return await orderService.getRecentPendingOrder();
  } catch (e) {
    // Return null if no pending orders or error
    return null;
  }
});

// All orders provider
final allOrdersProvider = FutureProvider.autoDispose<List<OrderResponse>>((ref) async {
  final orderService = ref.watch(orderServiceProvider);
  
  try {
    final orders = await orderService.getAllOrders();
    return orders ?? [];
  } catch (e) {
    // Return empty list if error
    return [];
  }
});

// Delivery status for recent order
final recentOrderDeliveryStatusProvider = FutureProvider.autoDispose<DeliveryStatusResponse?>((ref) async {
  final recentOrderAsync = ref.watch(recentPendingOrderWithRefreshProvider);
  
  return recentOrderAsync.when(
    data: (order) async {
      if (order == null) return null;
      
      try {
        final deliveryService = ref.watch(deliveryServiceProvider);
        return await deliveryService.getDeliveryStatus(order.id);
      } catch (e) {
        // Return null if delivery status not available
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Combined order timeline data
class OrderTimelineData {
  final OrderResponse? order;
  final DeliveryStatusResponse? deliveryStatus;
  
  OrderTimelineData({
    this.order,
    this.deliveryStatus,
  });
  
  bool get hasActiveOrder => order != null;
  bool get hasDeliveryTracking => deliveryStatus != null;
}

final orderTimelineDataProvider = FutureProvider.autoDispose<OrderTimelineData>((ref) async {
  final orderAsync = ref.watch(recentPendingOrderWithRefreshProvider);
  final deliveryAsync = ref.watch(recentOrderDeliveryStatusProvider);
  
  // Wait for both to complete
  final order = await orderAsync.when(
    data: (data) => data,
    loading: () => null,
    error: (_, __) => null,
  );
  
  final deliveryStatus = await deliveryAsync.when(
    data: (data) => data,
    loading: () => null,
    error: (_, __) => null,
  );
  
  return OrderTimelineData(
    order: order,
    deliveryStatus: deliveryStatus,
  );
});

// Auto-refresh provider that responds to WebSocket updates
class OrderTimelineNotifier extends AutoDisposeAsyncNotifier<OrderTimelineData> {
  Timer? _hideTimer;

  @override
  Future<OrderTimelineData> build() async {
    // Cancel any existing timer
    _hideTimer?.cancel();
    
    // Listen to WebSocket updates
    ref.listen<AsyncValue<DeliveryUpdateEvent>>(
      deliveryUpdatesProvider,
      (previous, next) {
        next.whenData((event) {
          // Refresh when delivery update received
          ref.invalidateSelf();
        });
      },
    );
    
    ref.listen<AsyncValue<PaymentUpdateEvent>>(
      paymentUpdatesProvider,
      (previous, next) {
        next.whenData((event) {
          // Refresh when payment update received
          ref.invalidateSelf();
        });
      },
    );
    
    // Cleanup timer when provider is disposed
    ref.onDispose(() {
      _hideTimer?.cancel();
    });
    
    // Get initial data
    final orderService = ref.watch(orderServiceProvider);
    final deliveryService = ref.watch(deliveryServiceProvider);
    
    try {
      final order = await orderService.getRecentPendingOrder();
      
      if (order == null) {
        return OrderTimelineData();
      }
      
      // Check if order should be hidden based on completion status and time
      if (_shouldHideCompletedOrder(order)) {
        return OrderTimelineData();
      }
      
      DeliveryStatusResponse? deliveryStatus;
      try {
        deliveryStatus = await deliveryService.getDeliveryStatus(order.id);
        
        // Also check delivery status for completion
        if (_shouldHideCompletedOrderByDeliveryStatus(order, deliveryStatus)) {
          return OrderTimelineData();
        }
      } catch (e) {
        // Delivery status not available
      }
      
      // Set up timer to hide completed/canceled orders after 2 minutes
      _setupHideTimer(order, deliveryStatus);
      
      return OrderTimelineData(
        order: order,
        deliveryStatus: deliveryStatus,
      );
    } catch (e) {
      return OrderTimelineData();
    }
  }
  
  // Set up timer to automatically hide completed orders after 2 minutes
  void _setupHideTimer(OrderResponse order, DeliveryStatusResponse? deliveryStatus) {
    final now = DateTime.now();
    final updatedAt = order.updatedAt;
    final timeSinceupdatedAt = now.difference(updatedAt);

    // Check if order is completed/canceled
    bool isCompleted = false;
    
    // Check order status
    if (order.status.toLowerCase() == 'completed' || 
        order.status.toLowerCase() == 'canceled' ||
        order.status.toLowerCase() == 'delivered') {
      isCompleted = true;
    }
    
    // Check delivery status
    if (!isCompleted && deliveryStatus != null) {
      try {
        MonitoringStatus monitoringStatus = parseMonitoringStatus(deliveryStatus.status);
        OrderStatus currentOrderStatus = getOrderStatusFromMonitoring(monitoringStatus);
        
        if (currentOrderStatus == OrderStatus.completed || currentOrderStatus == OrderStatus.canceled) {
          isCompleted = true;
        }
      } catch (e) {
        // Fall back to string comparison
        if (deliveryStatus.status.toLowerCase() == 'completed' || 
            deliveryStatus.status.toLowerCase() == 'canceled' ||
            deliveryStatus.status.toLowerCase() == 'delivered') {
          isCompleted = true;
        }
      }
    }
    
    // If order is completed and hasn't reached 2 minutes yet, set timer
    if (isCompleted && timeSinceupdatedAt.inMinutes < 2) {
      final remainingTime = const Duration(minutes: 2) - timeSinceupdatedAt;
      
      _hideTimer = Timer(remainingTime, () {
        // Refresh to hide the order
        ref.invalidateSelf();
      });
      
      debugPrint('Order ${order.orderNo} will be hidden in ${remainingTime.inSeconds} seconds');
    }
  }
  
  // Check if completed/canceled order should be hidden after 2 minutes
  bool _shouldHideCompletedOrder(OrderResponse order) {
    final now = DateTime.now();
    final orderCreatedAt = order.createdAt;
    final timeDifference = now.difference(orderCreatedAt);
    
    // If order is completed or canceled and more than 2 minutes have passed, hide it
    if (order.status.toLowerCase() == 'completed' || 
        order.status.toLowerCase() == 'canceled' ||
        order.status.toLowerCase() == 'delivered') {
      return timeDifference.inMinutes >= 2;
    }
    
    return false;
  }
  
  // Check if order should be hidden based on delivery status
  bool _shouldHideCompletedOrderByDeliveryStatus(OrderResponse order, DeliveryStatusResponse deliveryStatus) {
    final now = DateTime.now();
    final orderCreatedAt = order.createdAt;
    final timeDifference = now.difference(orderCreatedAt);
    
    // Parse monitoring status to check if completed
    try {
      MonitoringStatus monitoringStatus = parseMonitoringStatus(deliveryStatus.status);
      OrderStatus currentOrderStatus = getOrderStatusFromMonitoring(monitoringStatus);
      
      // If order status indicates completion and more than 2 minutes have passed, hide it
      if (currentOrderStatus == OrderStatus.completed || currentOrderStatus == OrderStatus.canceled) {
        return timeDifference.inMinutes >= 2;
      }
    } catch (e) {
      // If parsing fails, fall back to string comparison
      if (deliveryStatus.status.toLowerCase() == 'completed' || 
          deliveryStatus.status.toLowerCase() == 'canceled' ||
          deliveryStatus.status.toLowerCase() == 'delivered') {
        return timeDifference.inMinutes >= 2;
      }
    }
    
    return false;
  }
  
  // Method to manually refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final orderTimelineNotifierProvider = AutoDisposeAsyncNotifierProvider<OrderTimelineNotifier, OrderTimelineData>(
  () => OrderTimelineNotifier(),
);
