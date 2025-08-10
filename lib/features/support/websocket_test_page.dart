import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/components/websocket_widgets.dart';

class WebSocketTestPage extends ConsumerStatefulWidget {
  const WebSocketTestPage({super.key});

  @override
  ConsumerState<WebSocketTestPage> createState() => _WebSocketTestPageState();
}

class _WebSocketTestPageState extends ConsumerState<WebSocketTestPage> {
  String _userId = 'user123'; // Example user ID

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() async {
    // Get the current user ID from auth provider if available
    final userToken = await ref.read(currentUserTokenProvider.future);
    if (userToken != null) {
      // Extract user ID from token or use authenticated user ID
      _userId = 'authenticated_user_id'; // Replace with actual user ID extraction
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final isConnected = ref.watch(isConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Test'),
        actions: const [
          WebSocketStatusWidget(),
        ],
      ),
      body: WebSocketEventsListener(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle : Icons.error,
                            color: isConnected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            connectionStatus.when(
                              data: (status) => status.toString().split('.').last,
                              loading: () => 'Loading...',
                              error: (_, __) => 'Error',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          WebSocketConnectionButton(userId: _userId),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: isConnected
                                ? () {
                                    final webSocketManager = ref.read(webSocketManagerProvider);
                                    webSocketManager.joinUserRoom(_userId);
                                  }
                                : null,
                            child: const Text('Join User Room'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Events',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildEventStreamCard(
                        'Delivery Updates',
                        ref.watch(deliveryUpdatesProvider),
                        Icons.local_shipping,
                      ),
                      const SizedBox(height: 8),
                      _buildEventStreamCard(
                        'Payment Updates',
                        ref.watch(paymentUpdatesProvider),
                        Icons.payment,
                      ),
                      const SizedBox(height: 8),
                      _buildEventStreamCard(
                        'Notifications',
                        ref.watch(notificationsProvider),
                        Icons.notifications,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebSocket Usage Instructions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Connect to establish WebSocket connection\n'
                        '2. Join User Room to receive user-specific events\n'
                        '3. Listen for delivery, payment, and notification events\n'
                        '4. Events will be displayed as snackbars when received',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventStreamCard(String title, AsyncValue eventStream, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  eventStream.when(
                    data: (event) => 'Last event: ${DateTime.now().toString().substring(11, 19)}',
                    loading: () => 'Waiting for events...',
                    error: (_, __) => 'Error listening to events',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          eventStream.when(
            data: (_) => const Icon(Icons.check_circle, color: Colors.green, size: 16),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Icon(Icons.error, color: Colors.red, size: 16),
          ),
        ],
      ),
    );
  }
}
