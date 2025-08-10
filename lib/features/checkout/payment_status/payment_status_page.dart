import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/order_service.dart';
import '../../../core/di/service_locator.dart';
enum PaymentStatus {
  success,
  failed,
  cancel;

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return PaymentStatus.success;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancel':
        return PaymentStatus.cancel;
      default:
        return PaymentStatus.failed;
    }
  }
}

class PaymentStatusPage extends StatefulWidget {
  final String paymentMethod; // e.g., "maya"
  final String status; // success, failed, cancel
  final String? orderId;

  const PaymentStatusPage({
    super.key,
    required this.paymentMethod,
    required this.status,
    this.orderId,
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  bool _isLoadingOrder = false;
  OrderResponse? _order;
  String? _orderError;
  late PaymentStatus _paymentStatus;

  @override
  void initState() {
    super.initState();
    _paymentStatus = PaymentStatus.fromString(widget.status);
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _loadOrderDetails();
    }
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoadingOrder = true;
      _orderError = null;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final order = await orderService.getCustomerOrderMasked(widget.orderId!);
      setState(() {
        _order = order;
        _isLoadingOrder = false;
      });
    } catch (e) {
      setState(() {
        _orderError = 'Failed to load order details: $e';
        _isLoadingOrder = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 0 : 16,
            vertical: 20,
          ),
          child: isWeb
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildReceiptContent(theme),
                  ),
                )
              : _buildReceiptContent(theme),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getPaymentMethodIcon(),
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Paid via ${widget.paymentMethod.toUpperCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(ThemeData theme) {
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoadingOrder) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading order details...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_orderError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              _orderError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildOrderDetailRow(theme, 'Order ID', '#${widget.orderId}'),
          
          if (_order != null) ...[
            const SizedBox(height: 8),
            _buildOrderDetailRow(
              theme, 
              'Total Amount', 
              '₱${_order!.totalAmountPay.toStringAsFixed(2)}'
            ),
            if (_order!.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildOrderDetailRow(
                theme, 
                'Items', 
                '${_order!.items.length} item${_order!.items.length > 1 ? 's' : ''}'
              ),
            ],
            if (_order!.deliveryInfo.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildOrderDetailRow(
                theme, 
                'Delivery', 
                _order!.deliveryInfo.address,
                isAddress: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOrderDetailRow(ThemeData theme, String label, String value, {bool isAddress = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: isAddress ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_paymentStatus == PaymentStatus.success) ...[
            // if (widget.orderId != null && widget.orderId!.isNotEmpty)
            //   _buildPrimaryButton(
            //     theme, 
            //     'Track Order', 
            //     () => context.go('/order/tracking/${widget.orderId}')
            //   ),
            // const SizedBox(height: 12),
            _buildTextAction(theme, 'Continue Shopping', () => context.go('/home')),
          ] else if (_paymentStatus == PaymentStatus.failed) ...[
            const SizedBox(height: 16),
            _buildTextAction(theme, 'Back to Home', () => context.go('/home')),
          ] else if (_paymentStatus == PaymentStatus.cancel) ...[
            const SizedBox(height: 16),
            _buildTextAction(theme, 'Back to Home', () => context.go('/home')),
          ],
        ],
      ),
    );
  }

  Widget _buildTextAction(ThemeData theme, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildReceiptContent(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Receipt Header
          _buildReceiptHeader(theme),
          
          // Dotted Line Divider
          _buildDottedDivider(theme),
          
          // Order Details Section
          if (widget.orderId != null && widget.orderId!.isNotEmpty) ...[
            _buildOrderInfo(theme),
            _buildDottedDivider(theme),
          ],
          
          // Payment Method Section
          _buildPaymentMethodInfo(theme),
          
          // Dotted Line Divider
          _buildDottedDivider(theme),
          
          // Action Section
          _buildActionSection(theme),
          
          // Receipt Footer
          _buildReceiptFooter(theme),
        ],
      ),
    );
  }

  Widget _buildReceiptHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(),
            size: 32,
            color: _getStatusColor(),
          ),
          const SizedBox(height: 12),
          Text(
            _getReceiptHeaderTitle(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusMessage(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            DateTime.now().toString().substring(0, 19),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider(ThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: CustomPaint(
        painter: DottedLinePainter(color: theme.dividerColor),
        size: const Size(double.infinity, 1),
      ),
    );
  }

  Widget _buildReceiptFooter(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Text(
            _getReceiptFooterMessage(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: _getStatusColor(),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getReceiptFooterSubMessage(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for status content
  IconData _getStatusIcon() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return Icons.check_circle_outline;
      case PaymentStatus.failed:
        return Icons.error_outline;
      case PaymentStatus.cancel:
        return Icons.cancel_outlined;
    }
  }

  String _getReceiptHeaderTitle() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return 'Payment Receipt';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.cancel:
        return 'Payment Cancelled';
    }
  }

  String _getReceiptFooterMessage() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return 'Thank you for your order!';
      case PaymentStatus.failed:
        return 'Payment unsuccessful';
      case PaymentStatus.cancel:
        return 'Payment was cancelled';
    }
  }

  String _getReceiptFooterSubMessage() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return 'Keep this receipt for your records';
      case PaymentStatus.failed:
        return 'Please try again with a different payment method';
      case PaymentStatus.cancel:
        return 'You can complete your payment anytime';
    }
  }

  String _getStatusMessage() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return widget.orderId != null
            ? 'Your payment has been processed successfully. Your order is confirmed and will be prepared shortly.'
            : 'Your payment has been processed successfully.';
      case PaymentStatus.failed:
        return 'Your payment could not be processed. Please try again or use a different payment method.';
      case PaymentStatus.cancel:
        return 'You have cancelled the payment. Your order has not been processed.';
    }
  }

  Color _getStatusColor() {
    switch (_paymentStatus) {
      case PaymentStatus.success:
        return const Color(0xFF4CAF50); // Success green
      case PaymentStatus.failed:
        return const Color(0xFFF44336); // Error red
      case PaymentStatus.cancel:
        return const Color(0xFFFF9800); // Warning orange
    }
  }

  IconData _getPaymentMethodIcon() {
    switch (widget.paymentMethod.toLowerCase()) {
      case 'maya':
        return Icons.account_balance_wallet;
      case 'gcash':
        return Icons.payment;
      case 'card':
        return Icons.credit_card;
      case 'paypal':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }
}

// Custom painter for dotted lines
class DottedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DottedLinePainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 4.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
