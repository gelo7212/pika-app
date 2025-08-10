import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/models/websocket_models.dart';

class WebSocketStatusWidget extends ConsumerWidget {
  const WebSocketStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final isConnected = ref.watch(isConnectedProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(connectionStatus),
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(AsyncValue<WebSocketConnectionStatus> connectionStatus) {
    return connectionStatus.when(
      data: (status) {
        switch (status) {
          case WebSocketConnectionStatus.connected:
            return 'Connected';
          case WebSocketConnectionStatus.connecting:
            return 'Connecting...';
          case WebSocketConnectionStatus.reconnecting:
            return 'Reconnecting...';
          case WebSocketConnectionStatus.disconnected:
            return 'Disconnected';
          case WebSocketConnectionStatus.error:
            return 'Connection Error';
        }
      },
      loading: () => 'Loading...',
      error: (_, __) => 'Error',
    );
  }
}

class WebSocketEventsListener extends ConsumerWidget {
  final Widget child;

  const WebSocketEventsListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to delivery updates
    ref.listen<AsyncValue<DeliveryUpdateEvent>>(
      deliveryUpdatesProvider,
      (previous, next) {
        next.whenData((event) {
          _showDeliveryUpdateSnackBar(context, event);
        });
      },
    );

    // Listen to payment updates
    ref.listen<AsyncValue<PaymentUpdateEvent>>(
      paymentUpdatesProvider,
      (previous, next) {
        next.whenData((event) {
          _showPaymentUpdateSnackBar(context, event);
        });
      },
    );

    // Listen to notifications
    ref.listen<AsyncValue<NotificationEvent>>(
      notificationsProvider,
      (previous, next) {
        next.whenData((event) {
          _showNotificationSnackBar(context, event);
        });
      },
    );

    // Listen to WebSocket errors
    ref.listen<AsyncValue<String>>(
      webSocketErrorsProvider,
      (previous, next) {
        next.whenData((error) {
          _showErrorSnackBar(context, error);
        });
      },
    );

    return child;
  }

  void _showDeliveryUpdateSnackBar(BuildContext context, DeliveryUpdateEvent event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ${event.orderId}: ${event.status}'),
        backgroundColor: _getDeliveryStatusColor(event.status),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to order details or tracking page
            debugPrint('Navigate to order ${event.orderId}');
          },
        ),
      ),
    );
  }

  void _showPaymentUpdateSnackBar(BuildContext context, PaymentUpdateEvent event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment ${event.paymentStatus} for order ${event.orderId}',
        ),
        backgroundColor: event.paymentStatus == 'success' ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showNotificationSnackBar(BuildContext context, NotificationEvent event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(event.message),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection Error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getDeliveryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ready_for_pickup':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'on_the_way':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'failed':
      case 'returned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class WebSocketConnectionButton extends ConsumerWidget {
  final String userId;

  const WebSocketConnectionButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    final webSocketManager = ref.watch(webSocketManagerProvider);

    return ElevatedButton(
      onPressed: () async {
        try {
          if (isConnected) {
            await webSocketManager.disconnect();
          } else {
            await webSocketManager.connectUser(userId);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isConnected ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
      ),
      child: Text(isConnected ? 'Disconnect' : 'Connect'),
    );
  }
}
