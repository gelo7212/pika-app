import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/order_service.dart';
import '../../core/routing/navigation_extensions.dart';

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Completed', 'Pending', 'Cancelled', 'Expired', 'For Refund'];

  @override
  Widget build(BuildContext context) {
    final allOrdersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Order History',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Filter Pills - Clean design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected 
                                ? Colors.white 
                                : const Color(0xFF757575),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Orders List - Real data from API
          Expanded(
            child: allOrdersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load orders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(allOrdersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (orders) => _buildOrdersList(orders),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderResponse> orders) {
    // Filter orders based on selected filter
    final filteredOrders = selectedFilter == 'All' 
        ? orders 
        : orders.where((order) => _mapOrderStatus(order.status) == selectedFilter).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: const Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              selectedFilter == 'All' 
                  ? 'You haven\'t placed any orders yet'
                  : 'No ${selectedFilter.toLowerCase()} orders found',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredOrders.length,
      separatorBuilder: (context, index) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 16),
        color: const Color(0xFFE5E5E5),
      ),
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildOrderItem(order);
      },
    );
  }

  // Map order status from API to display status
  String _mapOrderStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return 'Completed';
      case 'pending':
      case 'confirmed':
      case 'preparing':
      case 'ready':
      case 'assigned':
      case 'picked_up':
      case 'on_route':
        return 'Pending';
      case 'canceled':
        return 'Canceled';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Failed';
      case 'expired':
        return 'Expired';
      case 'for refund':
      case 'for_refund':
        return 'For Refund';
      default:
        return 'Pending';
    }
  }

  // Check if expired payment can be retried (within 2 hours)
  bool _canRetryExpiredPayment(OrderResponse order) {
    if (_mapOrderStatus(order.status) != 'Expired') return false;
    
    if (order.paymentMethod.isEmpty) return false;
    
    final paymentUpdatedAt = order.paymentMethod[0].updatedAt;
    final now = DateTime.now();
    final timeDifference = now.difference(paymentUpdatedAt);
    
    // Allow retry if expired less than 2 hours ago
    return timeDifference.inHours < 2;
  }

  Widget _buildOrderItem(OrderResponse order) {
    final status = _mapOrderStatus(order.status);
    final statusColor = _getStatusColor(status);
    
    return GestureDetector(
      onTap: () => _showOrderDetails(order),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderNo}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Date
            Text(
              DateFormat('MMM dd, yyyy • h:mm a').format(order.orderDate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF757575),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Items Preview - Show first 2 items
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.take(2).map((item) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '${item.qty}x ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.itemName,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.items.length > 2)
                  Text(
                    '... and ${order.items.length - 2} more items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF757575),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Bottom Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${order.totalAmountPay.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'Completed')
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reorder feature coming soon!')),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Reorder',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    else if (status == 'Pending')
                      TextButton(
                        onPressed: () {
                          context.pushRoute('/order/tracking/${order.id}');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Track',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    else if (status == 'For Refund')
                      TextButton(
                        onPressed: () {
                          context.pushRoute('/order/tracking/${order.id}');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Ask for Refund',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.red[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (status == 'Expired' && _canRetryExpiredPayment(order))
                      TextButton(
                        onPressed: () {
                          context.go('/order/checkout/${order.id}');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Retry Payment',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.orange[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    // Use different colors for different statuses
    switch (status) {
      case 'For Refund':
        return Colors.red[600]!;
      case 'Completed':
        return Colors.green[600]!;
      case 'Pending':
        return Colors.orange[600]!;
      case 'Cancelled':
      case 'Canceled':
        return Colors.grey[600]!;
      case 'Expired':
        return Colors.red[400]!;
      case 'Failed':
        return Colors.red[700]!;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _showOrderDetails(OrderResponse order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Order #${order.orderNo}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy • h:mm a').format(order.orderDate),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF757575),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _mapOrderStatus(order.status),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Items
                Text(
                  'Items (${order.items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: order.items.length,
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant_outlined,
                                size: 20,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.size.isNotEmpty)
                                    Text(
                                      'Size: ${item.size}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                  if (item.addons.isNotEmpty)
                                    Text(
                                      'Addons: ${item.addons.map((addon) => addon).join(', ')}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.qty}x',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                Text(
                                  '₱${item.totalAmount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Divider
                Container(
                  height: 1,
                  color: const Color(0xFFE5E5E5),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),
                
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '₱${order.totalAmountPay.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
