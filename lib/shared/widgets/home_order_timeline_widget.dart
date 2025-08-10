import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/services/order_service.dart';
import '../../core/models/delivery_status_model.dart';
import '../../core/models/websocket_models.dart';
import '../../core/interfaces/auth_interface.dart';
import '../../core/di/service_locator.dart';
import '../components/order_timeline_widget.dart';

class HomeOrderTimelineWidget extends ConsumerStatefulWidget {
  const HomeOrderTimelineWidget({super.key});

  @override
  ConsumerState<HomeOrderTimelineWidget> createState() =>
      _HomeOrderTimelineWidgetState();
}

class _HomeOrderTimelineWidgetState
    extends ConsumerState<HomeOrderTimelineWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOut,
    ));

    // Ensure WebSocket connection is established for real-time updates
    _ensureWebSocketConnection();
  }

  void _ensureWebSocketConnection() async {
    // Ensure WebSocket is connected for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final webSocketManager = ref.read(webSocketManagerProvider);
        final isConnected = ref.read(isConnectedProvider);
        
        if (!isConnected) {
          // Try to get user ID and connect
          final authService = serviceLocator<AuthInterface>();
          final token = await authService.getCurrentUserToken();
          
          if (token != null) {
            final payload = await authService.decodeToken(token);
            if (payload != null) {
              await webSocketManager.connectUser(payload.sub);
              debugPrint('WebSocket connected for home order timeline');
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to ensure WebSocket connection in home timeline: $e');
      }
    });
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderTimelineAsync = ref.watch(orderTimelineNotifierProvider);
    final isConnected = ref.watch(isConnectedProvider);

    // Listen to connection status changes
    ref.listen<AsyncValue<WebSocketConnectionStatus>>(
      connectionStatusProvider,
      (previous, next) {
        next.whenData((status) {
          if (status == WebSocketConnectionStatus.connected) {
            debugPrint('WebSocket connected - home timeline will receive real-time updates');
          } else if (status == WebSocketConnectionStatus.disconnected) {
            debugPrint('WebSocket disconnected - home timeline using cached data only');
          }
        });
      },
    );

    // No need for manual WebSocket listeners here - the OrderTimelineNotifier 
    // already handles WebSocket updates automatically

    return orderTimelineAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (timelineData) {
        if (!timelineData.hasActiveOrder) {
          return const SizedBox.shrink();
        }

        // Animate in the timeline when order is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_slideAnimationController.isCompleted) {
            _slideAnimationController.forward();
          }
        });

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            height: 56, // Same height as AppBar
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: _buildOrderTimeline(timelineData, isConnected),
          ),
        );
      },
    );
  }

  Widget _buildOrderTimeline(OrderTimelineData timelineData, bool isConnected) {
    final order = timelineData.order!;
    final deliveryStatus = timelineData.deliveryStatus;

    // Create timeline steps based on order status
    final steps = _createTimelineSteps(order, deliveryStatus);

    return GestureDetector(
      onTap: () {
        // Navigate to order tracking page
        context.go('/order/tracking/${order.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Order info
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Order #${order.orderNo}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(order.status, deliveryStatus?.status),
                        size: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getStatusText(order.status, deliveryStatus?.status),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isConnected)
                        Icon(
                          Icons.wifi_off,
                          size: 12,
                          color: Colors.orange,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Timeline
            Expanded(
              flex: 3,
              child: OrderTimelineWidget(
                steps: steps,
                statusColor: Theme.of(context).colorScheme.primary,
                showAnimations: true,
                showStepLabels: false,
                iconSize: 16,
                lineHeight: 2,
              ),
            ),

            const SizedBox(width: 8),

            // Arrow
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  List<OrderTimelineStep> _createTimelineSteps(
    OrderResponse order,
    DeliveryStatusResponse? deliveryStatus,
  ) {
    final steps = <OrderTimelineStep>[];

    // Payment status
    final isPaid = deliveryStatus?.isPaid ?? order.isPaid ?? false;
    steps.add(OrderTimelineStep(
      title: 'Payment',
      description: isPaid ? 'Payment completed' : 'Payment pending',
      isCompleted: isPaid,
      timestamp: isPaid ? order.createdAt : null,
    ));

    if (isPaid) {
      // Get current monitoring status and convert to OrderStatus
      MonitoringStatus currentMonitoringStatus = MonitoringStatus.preparing;
      if (deliveryStatus?.status != null) {
        currentMonitoringStatus = parseMonitoringStatus(deliveryStatus!.status);
      }

      OrderStatus currentOrderStatus =
          getOrderStatusFromMonitoring(currentMonitoringStatus);

      // Preparing - show as completed when current status is beyond preparing
      final isPreparing =
          currentOrderStatus.index > OrderStatus.preparing.index;
      steps.add(OrderTimelineStep(
        title: 'Preparing',
        description: 'Order is being prepared',
        isCompleted: isPreparing,
        timestamp: currentOrderStatus.index >= OrderStatus.preparing.index
            ? order.createdAt
            : null,
      ));

      // Ready/Pickup - show as completed when current status is beyond ready
      final isReady =
          currentOrderStatus.index > OrderStatus.readyForPickup.index;
      steps.add(OrderTimelineStep(
        title: 'Ready',
        description: 'Ready for pickup/delivery',
        isCompleted: isReady,
        timestamp: currentOrderStatus.index >= OrderStatus.readyForPickup.index
            ? order.createdAt
            : null,
      ));

      // Out for delivery - show as completed when current status is beyond in progress
      final isOutForDelivery =
          currentOrderStatus.index > OrderStatus.inProgress.index;
      steps.add(OrderTimelineStep(
        title: 'Delivery',
        description: 'Out for delivery',
        isCompleted: isOutForDelivery,
        timestamp: currentOrderStatus.index >= OrderStatus.inProgress.index
            ? order.createdAt
            : null,
      ));

      // Delivered - matches tracking page logic
      final isDelivered = currentOrderStatus == OrderStatus.completed;
      steps.add(OrderTimelineStep(
        title: 'Delivered',
        description: 'Order delivered',
        isCompleted: isDelivered,
        timestamp: isDelivered ? order.updatedAt : null,
      ));
    }

    return steps;
  }

  IconData _getStatusIcon(String? orderStatus, String? deliveryStatus) {
    final status = deliveryStatus ?? orderStatus ?? 'pending';

    // Parse monitoring status and convert to OrderStatus
    MonitoringStatus monitoringStatus = parseMonitoringStatus(status);
    OrderStatus currentOrderStatus =
        getOrderStatusFromMonitoring(monitoringStatus);

    switch (currentOrderStatus) {
      case OrderStatus.cart:
        return Icons.shopping_cart;
      case OrderStatus.pending:
        return Icons.payment;
      case OrderStatus.confirmed:
        return Icons.restaurant;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.readyForPickup:
        return Icons.shopping_bag;
      case OrderStatus.inProgress:
        return Icons.delivery_dining;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.canceled:
        return Icons.cancel;
    }
  }

  String _getStatusText(String? orderStatus, String? deliveryStatus) {
    final status = deliveryStatus ?? orderStatus ?? 'pending';

    // Parse monitoring status and convert to OrderStatus
    MonitoringStatus monitoringStatus = parseMonitoringStatus(status);
    OrderStatus currentOrderStatus =
        getOrderStatusFromMonitoring(monitoringStatus);

    return currentOrderStatus.displayName;
  }
}
