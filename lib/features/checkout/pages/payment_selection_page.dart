import 'package:flutter/material.dart';
import '../../../core/services/order_service.dart';
import '../../../shared/components/custom_app_bar.dart';

class PaymentSelectionPage extends StatelessWidget {
  final OrderResponse orderResponse;

  const PaymentSelectionPage({
    super.key,
    required this.orderResponse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payment Method',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Payment Method',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Payment Methods List
            Expanded(
              child: ListView(
                children: [
                  _buildPaymentMethodTile(
                    context,
                    title: 'GCash / Maya',
                    subtitle: 'Pay via QR Code',
                    icon: Icons.qr_code,
                    onTap: () => _handleQRPayment(context),
                  ),
                  _buildPaymentMethodTile(
                    context,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when your order arrives',
                    icon: Icons.money,
                    onTap: () => _handleCashPayment(context),
                  ),
                  _buildPaymentMethodTile(
                    context,
                    title: 'Credit/Debit Card',
                    subtitle: 'Pay with your card',
                    icon: Icons.credit_card,
                    onTap: () => _handleCardPayment(context),
                  ),
                ],
              ),
            ),
            
            // Order Summary at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₱${orderResponse.totalAmountDue.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  void _handleQRPayment(BuildContext context) {
    // Check if QR payment is available in the order response
    final qrPayment = orderResponse.paymentMethod.firstWhere(
      (pm) => pm.method == 'QRPH',
      orElse: () => throw Exception('QR Payment not available'),
    );

    if (qrPayment.paymentProcessor?.redirectUrl != null) {
      _showQRPaymentDialog(context, qrPayment);
    } else {
      _showPaymentNotAvailable(context, 'QR Payment');
    }
  }

  void _handleCashPayment(BuildContext context) {
    _showPaymentNotAvailable(context, 'Cash on Delivery');
  }

  void _handleCardPayment(BuildContext context) {
    _showPaymentNotAvailable(context, 'Credit/Debit Card');
  }

  void _showQRPaymentDialog(BuildContext context, PaymentMethodResponse payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: ₱${payment.totalAmountDue.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Scan the QR code or use the payment link:'),
            const SizedBox(height: 16),
            if (payment.paymentProcessor?.qrCodeBody != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'QR Code: ${payment.paymentProcessor!.qrCodeBody}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: () {
                // TODO: Open payment URL
                Navigator.of(context).pop();
                _showPaymentSuccess(context);
              },
              child: const Text('Open Payment Link'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPaymentNotAvailable(BuildContext context, String paymentMethod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$paymentMethod will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Initiated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('Order #${orderResponse.orderNo}'),
            const SizedBox(height: 8),
            const Text('Your payment has been initiated. You will receive a confirmation once the payment is processed.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to payment selection
              Navigator.of(context).pop(); // Go back to order summary
              Navigator.of(context).pop(); // Go back to cart
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
