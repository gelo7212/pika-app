import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/delivery_status_model.dart';
import '../../core/models/websocket_models.dart';
import '../../core/interfaces/auth_interface.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/order_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/routing/navigation_extensions.dart';
import '../../core/providers/websocket_provider.dart';
import '../../shared/components/order_timeline_widget.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  DeliveryStatusResponse? _deliveryStatus;
  OrderResponse? _orderDetails;
  String? _error;

  OrderStatus _currentOrderStatus = OrderStatus.pending;
  MonitoringStatus _currentMonitoringStatus = MonitoringStatus.packing;

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadTrackingData();
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
              debugPrint('WebSocket connected for order tracking');
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to ensure WebSocket connection: $e');
      }
    });
  }

  void _handleConnectionStatusChange(WebSocketConnectionStatus status) {
    if (mounted) {
      switch (status) {
        case WebSocketConnectionStatus.connected:
          debugPrint('WebSocket connected - real-time updates enabled');
          break;
        case WebSocketConnectionStatus.disconnected:
          debugPrint('WebSocket disconnected - using manual refresh only');
          break;
        case WebSocketConnectionStatus.reconnecting:
          debugPrint('WebSocket reconnecting...');
          break;
        case WebSocketConnectionStatus.error:
          debugPrint('WebSocket connection error');
          break;
        case WebSocketConnectionStatus.connecting:
          debugPrint('WebSocket connecting...');
          break;
      }
    }
  }

  void _handleDeliveryUpdate(DeliveryUpdateEvent event) {
    if (mounted) {
      setState(() {
        // Update delivery status if we have it
        if (_deliveryStatus != null) {
          _deliveryStatus = DeliveryStatusResponse(
            orderId: _deliveryStatus!.orderId,
            driverDetails: _deliveryStatus!.driverDetails,
            status: event.status,
            isPaid: _deliveryStatus!.isPaid,
          );
        }
      });

      // Check if order status is "For Refund" - if so, ignore all delivery updates
      if (_isForRefund()) {
        // For refund orders, completely ignore delivery updates and maintain refund state
        debugPrint(
            'Ignoring delivery update for refund order ${event.orderId}: ${event.status}');
        return;
      }

      // Only update monitoring status for non-refund orders
      setState(() {
        _currentMonitoringStatus = _parseDeliveryStatus(event.status);
        _currentOrderStatus =
            getOrderStatusFromMonitoring(_currentMonitoringStatus);
      });

      // Restart pulse animation for visual feedback
      _pulseAnimationController.reset();
      _pulseAnimationController.repeat(reverse: true);

      // Refresh data in background to get latest information
      _refreshDataInBackground();

      debugPrint(
          'Delivery update received for order ${event.orderId}: ${event.status}');
    }
  }

  void _handlePaymentUpdate(PaymentUpdateEvent event) {
    if (mounted) {
      setState(() {
        // Update payment status
        if (_deliveryStatus != null) {
          _deliveryStatus = DeliveryStatusResponse(
            orderId: _deliveryStatus!.orderId,
            driverDetails: _deliveryStatus!.driverDetails,
            status: _deliveryStatus!.status,
            isPaid: event.paymentStatus == 'success',
          );
        }
      });

      // Refresh data in background to get latest information
      _refreshDataInBackground();

      debugPrint(
          'Payment update received for order ${event.orderId}: ${event.paymentStatus}');
    }
  }

  // Refresh data in background without showing loading indicator
  void _refreshDataInBackground() async {
    try {
      final deliveryService = serviceLocator<DeliveryService>();
      final orderService = serviceLocator<OrderService>();

      // Load both delivery status and order details concurrently
      final results = await Future.wait([
        deliveryService.getDeliveryStatus(widget.orderId),
        orderService.getCustomerOrderMasked(widget.orderId),
      ]);

      final deliveryStatus = results[0] as DeliveryStatusResponse;
      final orderDetails = results[1] as OrderResponse;

      if (mounted) {
        setState(() {
          _deliveryStatus = deliveryStatus;
          _orderDetails = orderDetails;
        });

        // Check if order status is "For Refund" - if so, ignore monitoring status completely
        if (orderDetails.status.toLowerCase() == 'for refund' ||
            orderDetails.status.toLowerCase() == 'for_refund') {
          // For refund orders, only focus on status, ignore monitoring status
          _currentOrderStatus =
              OrderStatus.canceled; // Use canceled as base state
          _currentMonitoringStatus =
              MonitoringStatus.canceled; // Set to canceled but won't be used
        } else {
          // For non-refund orders, use monitoring status logic
          _currentMonitoringStatus =
              parseMonitoringStatus(deliveryStatus.status);
          _currentOrderStatus =
              getOrderStatusFromMonitoring(_currentMonitoringStatus);
        }
      }

      debugPrint('Background refresh completed for order ${widget.orderId}');
    } catch (e) {
      debugPrint('Background refresh failed: $e');
      // Don't show error to user as this is background refresh
    }
  }

  MonitoringStatus _parseDeliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ready_for_pickup':
      case 'ready':
        return MonitoringStatus.ready;
      case 'picked_up':
        return MonitoringStatus.pickedUp;
      case 'on_the_way':
        return MonitoringStatus.onTheWay;
      case 'delivered':
        return MonitoringStatus.delivered;
      case 'failed':
      case 'returned':
        return MonitoringStatus.returned;
      case 'preparing':
        return MonitoringStatus.preparing;
      case 'cooking':
        return MonitoringStatus.cooking;
      case 'packing':
        return MonitoringStatus.packing;
      case 'driver_assigned':
        return MonitoringStatus.driverAssigned;
      case 'assigning_driver':
        return MonitoringStatus.assigningDriver;
      case 'arrived':
        return MonitoringStatus.arrived;
      case 'completed':
        return MonitoringStatus.completed;
      case 'canceled':
        return MonitoringStatus.canceled;
      default:
        return MonitoringStatus.new_;
    }
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTrackingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deliveryService = serviceLocator<DeliveryService>();
      final orderService = serviceLocator<OrderService>();

      // Load both delivery status and order details concurrently
      final results = await Future.wait([
        deliveryService.getDeliveryStatus(widget.orderId),
        orderService.getCustomerOrderMasked(widget.orderId),
      ]);

      final deliveryStatus = results[0] as DeliveryStatusResponse;
      final orderDetails = results[1] as OrderResponse;

      setState(() {
        _deliveryStatus = deliveryStatus;
        _orderDetails = orderDetails;
        _isLoading = false;
      });

      // Check if order status is "For Refund" - if so, ignore monitoring status completely
      if (orderDetails.status.toLowerCase() == 'for refund' ||
          orderDetails.status.toLowerCase() == 'for_refund') {
        // For refund orders, only focus on status, ignore monitoring status
        _currentOrderStatus =
            OrderStatus.canceled; // Use canceled as base state
        _currentMonitoringStatus =
            MonitoringStatus.canceled; // Set to canceled but won't be used
      } else {
        // For non-refund orders, use monitoring status logic
        _currentMonitoringStatus = parseMonitoringStatus(deliveryStatus.status);
        _currentOrderStatus =
            getOrderStatusFromMonitoring(_currentMonitoringStatus);
      }

      // Start animations after data is loaded
      _pulseAnimationController.repeat(reverse: true);
    } catch (e) {
      setState(() {
        _error = 'Failed to load tracking information: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;
    final isConnected = ref.watch(isConnectedProvider);

    // Setup WebSocket listeners
    ref.listen<AsyncValue<DeliveryUpdateEvent>>(
      deliveryUpdatesProvider,
      (previous, next) {
        next.whenData((deliveryEvent) {
          // Only process events for this specific order
          if (deliveryEvent.orderId == widget.orderId) {
            _handleDeliveryUpdate(deliveryEvent);
          }
        });
      },
    );

    ref.listen<AsyncValue<PaymentUpdateEvent>>(
      paymentUpdatesProvider,
      (previous, next) {
        next.whenData((paymentEvent) {
          // Only process events for this specific order
          if (paymentEvent.orderId == widget.orderId) {
            _handlePaymentUpdate(paymentEvent);
          }
        });
      },
    );

    ref.listen<AsyncValue<WebSocketConnectionStatus>>(
      connectionStatusProvider,
      (previous, next) {
        next.whenData((status) {
          _handleConnectionStatusChange(status);
        });
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Tracking'),
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.safeGoBack(),
        ),
        actions: [
          // WebSocket status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrackingData,
          ),
        ],
      ),
      body: _buildBody(theme, isWeb),
    );
  }

  Widget _buildBody(ThemeData theme, bool isWeb) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorView(theme);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: isWeb ? const EdgeInsets.all(16) : EdgeInsets.zero,
      child: isWeb
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildTrackingContent(theme),
              ),
            )
          : _buildTrackingContent(theme),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load tracking information',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrackingData,
              style: ElevatedButton.styleFrom(
                elevation: 0,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingContent(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    return Column(
      children: [
        // Order Header
        _buildOrderHeader(theme),
        SizedBox(height: isWeb ? 32 : 16),

        // Order Status Timeline
        _buildOrderTimeline(theme),
        SizedBox(height: isWeb ? 40 : 16),

        // Driver Information (if available)
        if (_deliveryStatus?.driverDetails != null) ...[
          _buildDriverInfo(theme),
          SizedBox(height: isWeb ? 32 : 16),
        ],

        // Order Details
        _buildOrderDetails(theme),
        SizedBox(height: isWeb ? 40 : 16),

        // Action Buttons
        _buildActionButtons(theme),
        const SizedBox(height: 24), // Add bottom spacing
      ],
    );
  }

  Widget _buildOrderHeader(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWeb ? Colors.grey[50] : Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${widget.orderId}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isForRefund()
                      ? 'For Refund'
                      : _currentMonitoringStatus.displayName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusDescription(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
          if (_orderDetails != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ordered: ${DateFormat('MMM dd, yyyy • h:mm a').format(_orderDetails!.orderDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderTimeline(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    // Show specific refund UI if order status is for refund
    if (_isForRefund()) {
      return _buildRefundStatusUI(theme, isWeb);
    }

    // Normal order progress timeline for non-refund orders
    final statusSteps = _getOrderStatusSteps();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Order Progress',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Horizontal Progress Timeline
          OrderTimelineWidget(
            steps: statusSteps
                .map((step) => OrderTimelineStep.fromOrderStatusStep(step))
                .toList(),
            statusColor: _getStatusColor(),
            showAnimations: true,
            showStepLabels: false,
          ),
          const SizedBox(height: 24),

          // Current Step Details
          _buildCurrentStepDetails(theme, statusSteps),
        ],
      ),
    );
  }

  Widget _buildRefundStatusUI(ThemeData theme, bool isWeb) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Refund Status Header
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Colors.red[50],
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: Colors.red[200]!, width: 1),
          //   ),
          //   child: Column(
          //     children: [
          //       Icon(
          //         Icons.money_off_rounded,
          //         size: 48,
          //         color: Colors.red[600],
          //       ),
          //       const SizedBox(height: 12),
          //       Text(
          //         'Order Eligible for Refund',
          //         style: theme.textTheme.titleLarge?.copyWith(
          //           fontWeight: FontWeight.w700,
          //           color: Colors.red[700],
          //         ),
          //         textAlign: TextAlign.center,
          //       ),
          //       const SizedBox(height: 8),
          //       Text(
          //         'This order is currently eligible for refund processing.',
          //         style: theme.textTheme.bodyMedium?.copyWith(
          //           color: Colors.red[600],
          //           height: 1.4,
          //         ),
          //         textAlign: TextAlign.center,
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 24),

          // Refund Process Steps
          _buildRefundSteps(theme),
          const SizedBox(height: 24),

          // Refund Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Refund Information',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• We will ask for your bank details to process the refund\n'
                  '• Refund processing typically takes 3-5 business days\n'
                  '• You will receive a confirmation email once processed\n'
                  '• Contact support if you need immediate assistance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSteps(ThemeData theme) {
    return Column(
      children: [
        // Step 1: Order Completed
        _buildRefundStep(
          theme: theme,
          stepNumber: 1,
          title: 'Order Processed',
          description: 'Your order was successfully processed',
          isCompleted: true,
          isActive: false,
          icon: Icons.check_circle,
        ),
        _buildRefundStepConnector(theme, isCompleted: true),

        // Step 2: Refund Eligible
        _buildRefundStep(
          theme: theme,
          stepNumber: 2,
          title: 'Refund Eligible',
          description: 'Order is now eligible for refund',
          isCompleted: true,
          isActive: true,
          icon: Icons.money_off,
        ),
        _buildRefundStepConnector(theme, isCompleted: false),

        // Step 3: Submit Refund Request
        _buildRefundStep(
          theme: theme,
          stepNumber: 3,
          title: 'Submit Request',
          description: 'Submit your refund request',
          isCompleted: false,
          isActive: false,
          icon: Icons.description,
        ),
        _buildRefundStepConnector(theme, isCompleted: false),

        // Step 4: Refund Processed
        _buildRefundStep(
          theme: theme,
          stepNumber: 4,
          title: 'Refund Processed',
          description: 'Refund will be processed to your account',
          isCompleted: false,
          isActive: false,
          icon: Icons.account_balance_wallet,
        ),
      ],
    );
  }

  Widget _buildRefundStep({
    required ThemeData theme,
    required int stepNumber,
    required String title,
    required String description,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
  }) {
    final Color stepColor = isCompleted
        ? Colors.red[600]!
        : isActive
            ? Colors.red[600]!
            : Colors.grey[400]!;

    return Row(
      children: [
        // Step Circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? stepColor : Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(
              color: stepColor,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted || isActive ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(width: 16),

        // Step Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCompleted || isActive
                      ? stepColor
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isCompleted || isActive
                      ? theme.colorScheme.onSurface.withOpacity(0.8)
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefundStepConnector(ThemeData theme,
      {required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
      width: 2,
      height: 24,
      decoration: BoxDecoration(
        color: isCompleted ? Colors.red[600] : Colors.grey[300],
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildCurrentStepDetails(
      ThemeData theme, List<OrderStatusStep> steps) {
    // Find the current active step or the last completed step
    OrderStatusStep? currentStep;

    for (int i = 0; i < steps.length; i++) {
      if (!steps[i].isCompleted) {
        currentStep = steps[i];
        break;
      }
    }

    // If all steps are completed, show the last step
    currentStep ??= steps.last;

    // Determine the appropriate icon based on the step title and status
    IconData stepIcon;
    if (currentStep.title == 'Canceled') {
      stepIcon = Icons.cancel;
    } else if (currentStep.title == 'Eligible for Refund' ||
        currentStep.title == 'Refund Request') {
      stepIcon = currentStep.isCompleted ? Icons.money_off : Icons.access_time;
    } else {
      stepIcon =
          currentStep.isCompleted ? Icons.check_circle : Icons.access_time;
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            stepIcon,
            color: _getStatusColor(),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  currentStep.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  currentStep.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (currentStep.timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('h:mm a').format(currentStep.timestamp!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo(ThemeData theme) {
    final driver = _deliveryStatus!.driverDetails!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delivery_dining,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Driver',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                backgroundImage:
                    driver.photo.isNotEmpty ? NetworkImage(driver.photo) : null,
                child: driver.photo.isEmpty
                    ? Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver.plateNumber,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_currentMonitoringStatus == MonitoringStatus.driverAssigned ||
                  _currentMonitoringStatus == MonitoringStatus.pickedUp ||
                  _currentMonitoringStatus == MonitoringStatus.onTheWay ||
                  _currentMonitoringStatus == MonitoringStatus.arrived)
                IconButton(
                  onPressed: () {
                    // TODO: Implement call driver functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Calling driver...'),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.phone,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(ThemeData theme) {
    if (_orderDetails == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Order summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '₱${_orderDetails!.totalAmountPay.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${_orderDetails!.items.length} item${_orderDetails!.items.length > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (_orderDetails!.deliveryInfo.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Address',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _orderDetails!.deliveryInfo.address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb ? BorderRadius.circular(16) : BorderRadius.zero,
        border: isWeb ? Border.all(color: Colors.grey[200]!, width: 1) : null,
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // For Refund Actions (check this first - highest priority - focus only on status)
          if (_isForRefund()) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to refund request page or show refund form
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refund request feature coming soon!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: Icon(
                  Icons.money_off,
                  size: 20,
                ),
                label: Text(
                  'Request Refund',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/support'),
                icon: Icon(
                  Icons.support_agent,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Contact Support',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ]
          // Payment Required Actions (if not paid and not for refund)
          else if (_deliveryStatus?.isPaid == false &&
              parseMonitoringStatus(_orderDetails!.monitoringStatus) !=
                  MonitoringStatus.onCart) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/order/checkout/${widget.orderId}/payment');
                },
                icon: Icon(
                  Icons.credit_card,
                  size: 20,
                ),
                label: Text(
                  'Pay Now',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF856404),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ]
          // Cart Actions (if items are in cart)
          else if (parseMonitoringStatus(_orderDetails!.monitoringStatus) ==
              MonitoringStatus.onCart) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/cart'); // Navigate to cart page
                },
                icon: Icon(
                  Icons.shopping_cart,
                  size: 20,
                ),
                label: Text(
                  'Go to Cart',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/menu');
                },
                icon: Icon(
                  Icons.add_shopping_cart,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Add More Items',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ]
          // Completed Order Actions
          else if (_currentOrderStatus == OrderStatus.completed) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to order again or rate order
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Order again feature coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Order Again'),
              ),
            ),
          ]
          // Canceled Order Actions
          else if (_currentOrderStatus == OrderStatus.canceled) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Order Again'),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/order-history'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View All Orders'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/support'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Get Help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _isForRefund() {
    return _orderDetails?.status.toLowerCase() == 'for refund' ||
        _orderDetails?.status.toLowerCase() == 'for_refund';
  }

  String _getStatusDescription() {
    // If payment is not completed, show payment pending message
    if (_deliveryStatus?.isPaid == false) {
      return 'Waiting for your payment. Please finish payment to process your order.';
    }

    // Handle For Refund status specifically - focus only on status
    if (_isForRefund()) {
      return 'Your order is eligible for refund. Please contact support or submit a refund request.';
    }

    // Check monitoring status for specific descriptions
    switch (_currentMonitoringStatus) {
      case MonitoringStatus.onCart:
        return 'Please complete your payment to start processing your order.';
      case MonitoringStatus.pickedUp:
        return 'Your order has been picked up and is on the way to your location.';
      case MonitoringStatus.onTheWay:
        return 'Your order is currently being delivered to your location.';
      case MonitoringStatus.arrived:
        return 'Your driver has arrived at your location.';
      case MonitoringStatus.preparing:
      case MonitoringStatus.cooking:
      case MonitoringStatus.packing:
        return 'The restaurant is preparing your delicious order.';
      case MonitoringStatus.ready:
        return 'Your order is ready and waiting for driver pickup.';
      case MonitoringStatus.assigningDriver:
        return 'We are assigning a driver to your order.';
      case MonitoringStatus.driverAssigned:
        return 'A driver has been assigned to your order.';
      case MonitoringStatus.completed:
      case MonitoringStatus.delivered:
        return 'Your order has been delivered successfully. Enjoy your meal!';
      case MonitoringStatus.canceled:
      case MonitoringStatus.returned:
        return 'Your order has been canceled.';
      case MonitoringStatus.new_:
        return 'Your order is being processed.';
    }
  }

  IconData _getStatusIcon() {
    // Handle For Refund status specifically - focus only on status
    if (_isForRefund()) {
      return Icons.money_off;
    }

    switch (_currentOrderStatus) {
      case OrderStatus.cart:
        return Icons.shopping_cart;
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return Icons.receipt_long;
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

  Color _getStatusColor() {
    // Use red color for "For Refund" status - focus only on status
    if (_isForRefund()) {
      return Colors.red[600]!;
    }

    // Use gray color for canceled orders
    if (_currentOrderStatus == OrderStatus.canceled) {
      return Colors.grey[600]!;
    }

    // Use theme primary color for all other status indicators
    return Theme.of(context).colorScheme.primary;
  }

  List<OrderStatusStep> _getOrderStatusSteps() {
    final now = DateTime.now();
    final orderTime = _orderDetails?.orderDate ?? now;

    // Handle For Refund orders FIRST - focus only on status, ignore everything else
    if (_isForRefund()) {
      return [
        OrderStatusStep(
          title: 'Order Processed',
          description: 'Your order was processed',
          isCompleted: true,
          timestamp: orderTime,
        ),
        OrderStatusStep(
          title: 'Eligible for Refund',
          description: 'Your order is eligible for refund',
          isCompleted: true,
          timestamp: now,
        ),
        OrderStatusStep(
          title: 'Refund Request',
          description: 'Submit your refund request',
          isCompleted: false,
          timestamp: null,
        ),
      ];
    }

    // If payment is not completed, show payment step first
    if (_deliveryStatus?.isPaid == false) {
      return [
        OrderStatusStep(
          title: 'Order On Cart',
          description: 'You have items in your cart',
          isCompleted: false,
          timestamp: null,
        ),
        OrderStatusStep(
          title: 'Payment',
          description: 'Complete your payment to proceed',
          isCompleted: false,
          timestamp: null,
        ),
        OrderStatusStep(
          title: 'Preparing',
          description: 'Restaurant will prepare your order',
          isCompleted: false,
          timestamp: null,
        ),
        OrderStatusStep(
          title: 'Ready',
          description: 'Order ready for pickup',
          isCompleted: false,
          timestamp: null,
        ),
        OrderStatusStep(
          title: 'Delivered',
          description: 'Order will be delivered to you',
          isCompleted: false,
          timestamp: null,
        ),
      ];
    }

    final steps = <OrderStatusStep>[
      OrderStatusStep(
        title: 'Order On Cart',
        description: 'You have items in your cart',
        isCompleted: _currentOrderStatus.index > OrderStatus.cart.index,
        timestamp: _currentOrderStatus.index >= OrderStatus.cart.index
            ? orderTime
            : null,
      ),
      OrderStatusStep(
        title: 'Preparing',
        description: 'The restaurant is preparing your order',
        isCompleted: _currentOrderStatus.index > OrderStatus.preparing.index,
        timestamp: _currentOrderStatus.index >= OrderStatus.preparing.index
            ? orderTime.add(const Duration(minutes: 5))
            : null,
      ),
      OrderStatusStep(
        title: 'Ready for Pickup',
        description: 'Your order is ready for pickup',
        isCompleted:
            _currentOrderStatus.index > OrderStatus.readyForPickup.index,
        timestamp: _currentOrderStatus.index >= OrderStatus.readyForPickup.index
            ? orderTime.add(const Duration(minutes: 15))
            : null,
      ),
      OrderStatusStep(
        title: 'Out for Delivery',
        description: 'Your order is on the way to you',
        isCompleted: _currentOrderStatus.index > OrderStatus.inProgress.index,
        timestamp: _currentOrderStatus.index >= OrderStatus.inProgress.index
            ? orderTime.add(const Duration(minutes: 25))
            : null,
      ),
      OrderStatusStep(
        title: 'Delivered',
        description: 'Your order has been delivered successfully',
        isCompleted: _currentOrderStatus == OrderStatus.completed,
        timestamp: _currentOrderStatus == OrderStatus.completed
            ? orderTime.add(const Duration(minutes: 45))
            : null,
      ),
    ];

    // Handle canceled orders
    if (_currentOrderStatus == OrderStatus.canceled) {
      return [
        OrderStatusStep(
          title: 'Canceled',
          description: 'Your order has been canceled',
          isCompleted: true,
          timestamp: now,
        ),
      ];
    }

    return steps;
  }
}

class OrderStatusStep {
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? timestamp;

  const OrderStatusStep({
    required this.title,
    required this.description,
    required this.isCompleted,
    this.timestamp,
  });
}
