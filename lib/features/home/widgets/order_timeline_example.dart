import 'package:flutter/material.dart';
import '../../../core/routing/navigation_extensions.dart';
import '../../../shared/components/order_timeline_widget.dart';

/// Example implementation showing how to use OrderTimelineWidget in the home page
/// This can be integrated into your existing home page to show order progress
class OrderTimelineExample extends StatelessWidget {
  const OrderTimelineExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Current Order',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Order #12345',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Timeline Widget - Now uses full width with even spacing
            OrderTimelineWidget(
              steps: _getSampleOrderSteps(),
              statusColor: Theme.of(context).colorScheme.primary,
              showAnimations: true,
              showStepLabels: false, // Set to true if you want step labels
              iconSize: MediaQuery.of(context).size.width < 768 ? 24 : 30, // Responsive icon size
              lineHeight: 3, // Thinner lines for home page
            ),
            
            const SizedBox(height: 16),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to order tracking page
                  context.pushRoute('/order/tracking/12345');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Track Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OrderTimelineStep> _getSampleOrderSteps() {
    return [
      OrderTimelineStep(
        title: 'Preparing',
        description: 'Restaurant is preparing your order',
        isCompleted: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        icon: Icons.restaurant,
      ),
      OrderTimelineStep(
        title: 'Ready',
        description: 'Order is ready for pickup',
        isCompleted: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        icon: Icons.shopping_bag,
      ),
      OrderTimelineStep(
        title: 'Out for Delivery',
        description: 'Your order is on the way',
        isCompleted: false, // Current step
        timestamp: null,
        icon: Icons.delivery_dining,
      ),
      OrderTimelineStep(
        title: 'Delivered',
        description: 'Order will be delivered to you',
        isCompleted: false,
        timestamp: null,
        icon: Icons.check_circle,
      ),
    ];
  }
}

/// Simplified version for smaller home page cards
class CompactOrderTimelineExample extends StatelessWidget {
  const CompactOrderTimelineExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #12345 - Out for Delivery',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Compact timeline - no animations, smaller icons
          OrderTimelineWidget(
            steps: _getCompactOrderSteps(),
            statusColor: Theme.of(context).colorScheme.primary,
            showAnimations: false, // No animations for compact version
            showStepLabels: false,
            iconSize: MediaQuery.of(context).size.width < 768 ? 16 : 20, // Very small icons, responsive
            lineHeight: 2, // Very thin lines
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Estimated delivery: 15-20 minutes',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  List<OrderTimelineStep> _getCompactOrderSteps() {
    return [
      OrderTimelineStep(
        title: 'Preparing',
        description: 'Restaurant is preparing your order',
        isCompleted: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      OrderTimelineStep(
        title: 'Ready',
        description: 'Order is ready for pickup',
        isCompleted: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      OrderTimelineStep(
        title: 'Delivering',
        description: 'Your order is on the way',
        isCompleted: false, // Current step
        timestamp: null,
      ),
      OrderTimelineStep(
        title: 'Delivered',
        description: 'Order completed',
        isCompleted: false,
        timestamp: null,
      ),
    ];
  }
}
