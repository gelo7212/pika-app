import 'package:customer_order_app/core/models/addon_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/order_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/components/custom_app_bar.dart';
import 'payment_selection_page.dart';

class OrderSummaryPage extends ConsumerStatefulWidget {
  final Order? order;
  final String? orderId;

  const OrderSummaryPage({
    super.key,
    required this.order,
  }) : orderId = null;

  const OrderSummaryPage.fromOrderId({
    super.key,
    required this.orderId,
  }) : order = null;

  @override
  ConsumerState<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends ConsumerState<OrderSummaryPage> {
  bool _isLoading = false;
  OrderResponse? _orderResponse;
  String? _error;
  String _selectedPaymentMethodId =
      ''; // Store payment method ID instead of method name
  List<PaymentMethodOption> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  String? _paymentMethodsError;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _createOrder();
    } else if (widget.orderId != null) {
      _fetchExistingOrder();
    }
  }

  Future<void> _createOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final response = await orderService.createCustomerOrder(widget.order!);
      setState(() {
        _orderResponse = response;
        _isLoading = false;
      });

      // Fetch payment methods after creating the order
      await _fetchPaymentMethods(response.storeId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchExistingOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final response = await orderService.getCustomerOrder(widget.orderId!);
      setState(() {
        _orderResponse = response;
        _isLoading = false;
      });

      // Fetch payment methods after getting the order
      await _fetchPaymentMethods(response.storeId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPaymentMethods(String storeId) async {
    setState(() {
      _isLoadingPaymentMethods = true;
      _paymentMethodsError = null;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final paymentMethods = await orderService.getStorePaymentMethods(storeId);
      setState(() {
        _paymentMethods = paymentMethods;
        _isLoadingPaymentMethods = false;

        // Set default payment method to the first available one's ID
        if (paymentMethods.isNotEmpty) {
          _selectedPaymentMethodId = paymentMethods.first.id;
        } else {
          // Set default fallback payment method
          _selectedPaymentMethodId = 'fallback_qrph';
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingPaymentMethods = false;
        _paymentMethodsError = e.toString();
        // Set default fallback payment method when error occurs
        _selectedPaymentMethodId = 'fallback_qrph';
      });
      print('Error fetching payment methods: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Order Summary',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(theme)
              : _orderResponse != null
                  ? _buildOrderSummary(theme)
                  : const Center(child: Text('No order data')),
      bottomNavigationBar: _orderResponse != null && _error == null
          ? _buildBottomBar(theme)
          : null,
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to create order',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createOrder,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme) {
    final order = _orderResponse!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Details Card
          _buildOrderDetailsCard(theme, order),
          const SizedBox(height: 16),

          // Items List
          _buildItemsSection(theme, order),
          const SizedBox(height: 16),

          // Delivery Information
          _buildDeliverySection(theme, order),
          const SizedBox(height: 16),

          // Pricing Breakdown
          _buildPricingSection(theme, order),
          const SizedBox(height: 16),

          // Payment Method Selection
          _buildPaymentMethodSection(theme),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard(ThemeData theme, OrderResponse order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderNo}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customer: ${order.customerName}',
              style: theme.textTheme.bodyLarge,
            ),
            if (order.orderComment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: ${order.orderComment}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Order Date: ${_formatDateTime(order.orderDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(ThemeData theme, OrderResponse order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items (${order.items.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map((item) => _buildItemTile(theme, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(ThemeData theme, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.qty}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.size.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Size: ${item.size}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Add-ons: ${_buildAddonText(item.addons)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (item.comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${item.comment}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${item.amountDue.toStringAsFixed(2)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.totalDiscount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '-₱${item.totalDiscount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(ThemeData theme, OrderResponse order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delivery_dining,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivery Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.location_on, 'Address', order.deliveryInfo.address),
            _buildInfoRow(
                Icons.phone, 'Contact', order.deliveryInfo.contactNumber),
            if (order.deliveryInfo.deliveryNotes.isNotEmpty)
              _buildInfoRow(
                  Icons.note, 'Notes', order.deliveryInfo.deliveryNotes),
            _buildInfoRow(
                Icons.local_shipping, 'Provider', order.deliveryProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(ThemeData theme, OrderResponse order) {
    // Calculate service fee for selected payment method
    double serviceFeeAmount = 0.0;
    PaymentMethodOption? selectedPaymentMethod;

    if (_selectedPaymentMethodId.isNotEmpty && _paymentMethods.isNotEmpty) {
      try {
        selectedPaymentMethod = _paymentMethods.firstWhere(
          (method) => method.id == _selectedPaymentMethodId,
        );

        if (selectedPaymentMethod.serviceFee > 0) {
          // Find platform fees in additional fees and subtract from total
          double platformFeeAmount = 0.0;
          for (final fee in order.additionalFee) {
            if (fee.name.toLowerCase().contains('platform') ||
                fee.name.toLowerCase().contains('app') ||
                fee.type.toLowerCase().contains('platform')) {
              platformFeeAmount += fee.amount;
            }
          }

          // Calculate base amount for service fee computation (total - platform fees)
          final baseAmountForServiceFee =
              order.totalAmountDue - platformFeeAmount;

          if (selectedPaymentMethod.isPercentage) {
            // Calculate percentage-based service fee
            serviceFeeAmount = baseAmountForServiceFee *
                (selectedPaymentMethod.serviceFee / 100);
          } else {
            // Fixed service fee
            serviceFeeAmount = selectedPaymentMethod.serviceFee;
          }
        }
      } catch (e) {
        // Payment method not found, no service fee
      }
    }

    // Calculate new total including service fee
    final totalWithServiceFee = order.totalAmountDue + serviceFeeAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPriceRow('Subtotal', order.basePrice),
            if (order.totalDiscount > 0)
              _buildPriceRow('Discount', -order.totalDiscount,
                  isDiscount: true),
            ...order.additionalFee
                .where((s) =>
                    !s.name.toLowerCase().contains('service') && s.amount >= 0)
                .map((fee) => _buildPriceRow(fee.name, fee.amount)),
            if (serviceFeeAmount > 0)
              _buildPriceRow('Service Fee', serviceFeeAmount),
            const Divider(),
            _buildPriceRow(
              'Total',
              totalWithServiceFee,
              isTotal: true,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Method',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingPaymentMethods)
              const Center(child: CircularProgressIndicator())
            else if (_paymentMethodsError != null)
              _buildPaymentMethodError(theme)
            else if (_paymentMethods.isEmpty)
              _buildPaymentMethodError(theme)
            else
              ..._paymentMethods
                  .map((paymentMethod) => _buildPaymentMethodOption(
                        paymentMethod.id,
                        paymentMethod.name,
                        _getPaymentMethodSubtitle(paymentMethod.method),
                        _getPaymentMethodIcon(paymentMethod.method),
                        theme,
                        serviceFee: paymentMethod.serviceFee,
                        isPercentage: paymentMethod.isPercentage,
                      )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodError(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.error.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load payment methods',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Using default payment options',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _fetchPaymentMethods(_orderResponse!.storeId),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFallbackPaymentMethods(theme),
      ],
    );
  }

  Widget _buildFallbackPaymentMethods(ThemeData theme) {
    return Column(
      children: [
        _buildPaymentMethodOption(
          'fallback_qrph',
          'GCash / Maya',
          'Pay via QR Code',
          Icons.qr_code,
          theme,
        ),
        _buildPaymentMethodOption(
          'fallback_cash',
          'Cash on Delivery',
          'Pay when your order arrives',
          Icons.money,
          theme,
        ),
        _buildPaymentMethodOption(
          'fallback_card',
          'Credit/Debit Card',
          'Pay with your card',
          Icons.credit_card,
          theme,
        ),
      ],
    );
  }

  String _getPaymentMethodSubtitle(String method) {
    switch (method) {
      case 'QRPH':
        return 'Pay via QR Code';
      case 'CASH':
        return 'Pay when your order arrives';
      case 'CARD':
        return 'Pay with your card';
      default:
        return 'Pay using this method';
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'QRPH':
        return Icons.qr_code;
      case 'CASH':
        return Icons.money;
      case 'CARD':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Widget _buildPaymentMethodOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    ThemeData theme, {
    double? serviceFee,
    bool? isPercentage,
  }) {
    final isSelected = _selectedPaymentMethodId == value;

    // Calculate actual service fee based on order total (minus platform fees)
    String serviceFeeText = '';
    double computedServiceFee = 0.0;

    if (serviceFee != null && serviceFee > 0 && _orderResponse != null) {
      // Find platform fees in additional fees and subtract from total
      double platformFeeAmount = 0.0;
      for (final fee in _orderResponse!.additionalFee) {
        if (fee.name.toLowerCase().contains('platform') ||
            fee.name.toLowerCase().contains('app') ||
            fee.type.toLowerCase().contains('platform')) {
          platformFeeAmount += fee.amount;
        }
      }

      // Calculate base amount for service fee computation (total - platform fees)
      final baseAmountForServiceFee =
          _orderResponse!.totalAmountDue - platformFeeAmount;

      if (isPercentage == true) {
        // Calculate percentage-based service fee
        computedServiceFee = baseAmountForServiceFee * (serviceFee / 100);
        serviceFeeText =
            ' (+${serviceFee.toStringAsFixed(1)}% = ₱${computedServiceFee.toStringAsFixed(2)})';
      } else {
        // Fixed service fee
        computedServiceFee = serviceFee;
        serviceFeeText = ' (+₱${computedServiceFee.toStringAsFixed(2)})';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : null,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethodId,
        onChanged: (String? newValue) {
          setState(() {
            _selectedPaymentMethodId = newValue!;
          });
        },
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title + serviceFeeText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount,
      {bool isDiscount = false, bool isTotal = false, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style ??
                TextStyle(
                  color: isTotal ? null : Colors.grey[700],
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            '${isDiscount ? '-' : ''}₱${amount.abs().toStringAsFixed(2)}',
            style: style?.copyWith(
                  color: isDiscount ? Colors.green : null,
                ) ??
                TextStyle(
                  color: isDiscount
                      ? Colors.green
                      : (isTotal ? null : Colors.grey[700]),
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final order = _orderResponse!;

    // Calculate service fee for selected payment method
    double serviceFeeAmount = 0.0;
    PaymentMethodOption? selectedPaymentMethod;

    if (_selectedPaymentMethodId.isNotEmpty && _paymentMethods.isNotEmpty) {
      try {
        selectedPaymentMethod = _paymentMethods.firstWhere(
          (method) => method.id == _selectedPaymentMethodId,
        );

        if (selectedPaymentMethod.serviceFee > 0) {
          // Find platform fees in additional fees and subtract from total
          double platformFeeAmount = 0.0;
          for (final fee in order.additionalFee) {
            if (fee.name.toLowerCase().contains('platform') ||
                fee.name.toLowerCase().contains('app') ||
                fee.type.toLowerCase().contains('platform')) {
              platformFeeAmount += fee.amount;
            }
          }

          // Calculate base amount for service fee computation (total - platform fees)
          final baseAmountForServiceFee =
              order.totalAmountDue - platformFeeAmount;

          if (selectedPaymentMethod.isPercentage) {
            // Calculate percentage-based service fee
            serviceFeeAmount = baseAmountForServiceFee *
                (selectedPaymentMethod.serviceFee / 100);
          } else {
            // Fixed service fee
            serviceFeeAmount = selectedPaymentMethod.serviceFee;
          }
        }
      } catch (e) {
        // Payment method not found, no service fee
      }
    }

    // Calculate total including service fee
    final totalWithServiceFee = order.totalAmountDue + serviceFeeAmount;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₱${totalWithServiceFee.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _placeOrder(order),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _placeOrder(OrderResponse order) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final updatedOrder = await orderService.updateCustomerOrderPayment(
        order.id,
        _selectedPaymentMethodId,
        order.storeId,
      );

      setState(() {
        _orderResponse = updatedOrder;
        _isLoading = false;
      });

      // Find the selected payment method to get its method type
      PaymentMethodOption? selectedPaymentMethod;
      if (_paymentMethods.isNotEmpty) {
        try {
          selectedPaymentMethod = _paymentMethods.firstWhere(
            (method) => method.id == _selectedPaymentMethodId,
          );
        } catch (e) {
          // If not found in the list, handle fallback cases
        }
      }

      // Handle different payment methods
      if (selectedPaymentMethod != null) {
        switch (selectedPaymentMethod.method) {
          case 'QRPH':
            _handleQRPayment(updatedOrder);
            break;
          case 'CASH':
            _handleCashPayment(updatedOrder);
            break;
          case 'CARD':
            _handleCardPayment(updatedOrder);
            break;
          case 'QRPH_XENDIT':
            _handleQRPayment(updatedOrder);
            break;
          default:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PaymentSelectionPage(orderResponse: updatedOrder),
              ),
            );
        }
      } else {
        // Handle fallback cases
        if (_selectedPaymentMethodId.startsWith('fallback_')) {
          final fallbackMethod = _selectedPaymentMethodId
              .replaceFirst('fallback_', '')
              .toLowerCase();
          switch (fallbackMethod) {
            case 'qrph':
              _handleQRPayment(updatedOrder);
              break;
            case 'cash':
              _handleCashPayment(updatedOrder);
              break;
            case 'card':
              _handleCardPayment(updatedOrder);
              break;
            default:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentSelectionPage(orderResponse: updatedOrder),
                ),
              );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleQRPayment(OrderResponse order) {
    // Navigate to payment route using GoRouter - payment page will fetch the checkout URL
    context.go('/order/checkout/${order.id}/payment');
  }

  void _handleCashPayment(OrderResponse order) {
    _showPaymentNotAvailable('Cash on Delivery');
  }

  void _handleCardPayment(OrderResponse order) {
    // Navigate to payment route using GoRouter - payment page will fetch the checkout URL
    context.go('/order/checkout/${order.id}/payment');
  }

  void _showPaymentNotAvailable(String paymentMethod) {
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

  Color _getStatusColor(String status) {
    // Use theme primary color for all status indicators
    return Theme.of(context).colorScheme.primary;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _buildAddonText(List<Addon> addons) {
    if (addons.isEmpty) return '';

    final addonTexts =
        addons.map((addon) => '${addon.qty}x ${addon.name}').toList();

    return 'Add-ons: ${addonTexts.join(', ')}';
  }
}
