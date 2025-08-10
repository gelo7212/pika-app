import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/services/order_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/providers/websocket_provider.dart';
import '../../../core/models/websocket_models.dart';
import '../../../core/interfaces/auth_interface.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final String orderId;

  const PaymentPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;
  String? _checkoutUrl;
  OrderResponse? _orderResponse;
  bool _isQRPayment = false;
  Timer? _countdownTimer;
  Duration? _remainingTime;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderAndInitializePayment();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handlePaymentEvent(PaymentUpdateEvent event) async {
    debugPrint(
        'Received payment event for order ${event.orderId}: ${event.paymentStatus}');

    // Show a subtle notification about the payment event
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment status update: ${event.paymentStatus}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      // Fetch latest order details to check payment status
      final orderService = serviceLocator<OrderService>();
      final orderResponse = await orderService.getCustomerOrder(widget.orderId);

      setState(() {
        _orderResponse = orderResponse;
      });

      debugPrint('Order fetched - isPaid: ${orderResponse.isPaid}');

      // Check if order is paid first
      if (orderResponse.isPaid == true) {
        debugPrint('Order is marked as paid, showing success');
        _handlePaymentSuccess();
        return;
      }

      // Check the first payment method status
      if (orderResponse.paymentMethod.isNotEmpty) {
        final paymentMethod = orderResponse.paymentMethod[0];
        final status = paymentMethod.status.toUpperCase();
        final isPaid = paymentMethod.isPaid;

        debugPrint('Payment method status: $status, isPaid: $isPaid');

        // Check isPaid status first
        if (isPaid) {
          debugPrint('Payment method is marked as paid, showing success');
          _handlePaymentSuccess();
          return;
        }

        // Then check status
        switch (status) {
          case 'COMPLETED':
          case 'SUCCESS':
          case 'PAID':
            debugPrint(
                'Payment status indicates success, showing success dialog');
            _handlePaymentSuccess();
            return;
          case 'CANCELED':
          case 'CANCELLED':
            debugPrint(
                'Payment status indicates canceled, showing canceled dialog');
            _handlePaymentCanceled();
            return;
          case 'FAILED':
          case 'FAIL':
            debugPrint(
                'Payment status indicates failed, showing failed dialog');
            _handlePaymentFailure();
            return;
          case 'PENDING':
            // Continue waiting for payment
            debugPrint('Payment still pending, continuing to wait...');
            break;
          default:
            debugPrint('Unknown payment status: $status');
        }
      }

      // Also check the WebSocket event status directly
      final eventStatus = event.paymentStatus.toUpperCase();
      debugPrint('WebSocket event status: $eventStatus');

      switch (eventStatus) {
        case 'SUCCESS':
        case 'COMPLETED':
        case 'PAID':
          debugPrint(
              'WebSocket event indicates success, showing success dialog');
          _handlePaymentSuccess();
          break;
        case 'FAILED':
        case 'FAIL':
          debugPrint('WebSocket event indicates failed, showing failed dialog');
          _handlePaymentFailure();
          break;
        case 'CANCELED':
        case 'CANCELLED':
          debugPrint(
              'WebSocket event indicates canceled, showing canceled dialog');
          _handlePaymentCanceled();
          break;
        default:
          debugPrint('WebSocket event status not handled: $eventStatus');
      }
    } catch (e) {
      debugPrint('Error handling payment event: $e');
    }
  }

  void _startCountdownTimer() {
    // Use 5 minutes from order creation as expiry time since quotation.expiresAt might not be available
    if (_orderResponse == null) {
      return;
    }

    final paymentUpdatedAt = _orderResponse!.paymentMethod.isNotEmpty
        ? _orderResponse!.paymentMethod[0].updatedAt
        : _orderResponse!.createdAt;
    // final expiresAt = orderCreatedAt.add(const Duration(minutes: 5));
    final expiresAt =
        _orderResponse!.deliveryInfo.deliveryDetails.quotation?.expiresAt ??
            paymentUpdatedAt.add(const Duration(minutes: 5));
    final now = DateTime.now();

    if (expiresAt.isBefore(now)) {
      setState(() {
        _isExpired = true;
        _remainingTime = Duration.zero;
      });
      return;
    }

    setState(() {
      _remainingTime = expiresAt.difference(now);
      _isExpired = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = expiresAt.difference(now);

      if (remaining.isNegative || remaining.inSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isExpired = true;
          _remainingTime = Duration.zero;
        });

        // Optionally redirect to expired status page after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isExpired) {
            final paymentMethodName = _getPaymentMethodDisplayName();
            context.go(
                '/payment/$paymentMethodName/expired?orderId=${widget.orderId}');
          }
        });
      } else {
        setState(() {
          _remainingTime = remaining;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative || duration.inSeconds <= 0) {
      return '00:00';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _ensureWebSocketConnection() async {
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
            debugPrint('WebSocket connected for payment updates');
          }
        }
      } else {
        debugPrint('WebSocket already connected for payment updates');
      }
    } catch (e) {
      debugPrint('Failed to ensure WebSocket connection: $e');
    }
  }

  Future<void> _fetchOrderAndInitializePayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = serviceLocator<OrderService>();
      final orderResponse = await orderService.getCustomerOrder(widget.orderId);

      setState(() {
        _orderResponse = orderResponse;
      });

      // Check order status first - redirect if not pending
      if (orderResponse.paymentMethod.isNotEmpty) {
        final paymentMethod = orderResponse.paymentMethod[0];
        final status = paymentMethod.status.toUpperCase();
        final isPaid = paymentMethod.isPaid;

        debugPrint(
            'Order status check - Status: $status, isPaid: $isPaid, orderIsPaid: ${orderResponse.isPaid}');

        // Check if order is already paid or completed
        if (orderResponse.isPaid == true || isPaid) {
          debugPrint('Order is already paid, redirecting to success page');
          final paymentMethodName = _getPaymentMethodDisplayName();
          context.go(
              '/payment/$paymentMethodName/success?orderId=${widget.orderId}');
          return;
        }

        // Check payment status and redirect if not pending
        switch (status) {
          case 'COMPLETED':
          case 'SUCCESS':
          case 'PAID':
            debugPrint(
                'Payment status is $status, redirecting to success page');
            final paymentMethodName = _getPaymentMethodDisplayName();
            context.go(
                '/payment/$paymentMethodName/success?orderId=${widget.orderId}');
            return;
          case 'CANCELED':
          case 'CANCELLED':
            debugPrint('Payment status is $status, redirecting to cancel page');
            final paymentMethodName = _getPaymentMethodDisplayName();
            context.go(
                '/payment/$paymentMethodName/cancel?orderId=${widget.orderId}');
            return;
          case 'FAILED':
          case 'FAIL':
            debugPrint('Payment status is $status, redirecting to failed page');
            final paymentMethodName = _getPaymentMethodDisplayName();
            context.go(
                '/payment/$paymentMethodName/failed?orderId=${widget.orderId}');
            return;
          case 'PENDING':
            debugPrint(
                'Payment status is pending, proceeding with payment interface');
            break;
          default:
            debugPrint('Unknown payment status: $status, treating as pending');
            break;
        }
      }

      // If we reach here, the payment is pending - proceed with normal payment flow
      // Check if the first payment method is QRPH_XENDIT
      if (orderResponse.paymentMethod.isNotEmpty &&
          orderResponse.paymentMethod[0].method == 'QRPH_XENDIT' &&
          orderResponse
                  .paymentMethod[0].paymentProcessor?.qrCodeBody.isNotEmpty ==
              true) {
        setState(() {
          _isQRPayment = true;
          _isLoading = false;
        });

        // Start countdown timer for payment expiry
        _startCountdownTimer();

        // Ensure WebSocket connection for payment updates
        _ensureWebSocketConnection();
        return;
      }

      // Find the payment method with redirectUrl for WebView
      String? checkoutUrl;
      for (final paymentMethod in orderResponse.paymentMethod) {
        if (paymentMethod.paymentProcessor?.redirectUrl.isNotEmpty == true) {
          checkoutUrl = paymentMethod.paymentProcessor!.redirectUrl;
          break;
        }
      }

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        setState(() {
          _checkoutUrl = checkoutUrl;
        });
        _initializeWebView();
      } else {
        setState(() {
          _error = 'No payment URL available for this order';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load order: $e';
        _isLoading = false;
      });
    }
  }

  void _initializeWebView() {
    if (_checkoutUrl == null || _checkoutUrl!.isEmpty) {
      setState(() {
        _error = 'No checkout URL available';
        _isLoading = false;
      });
      return;
    }

    _controller = WebViewController();

    try {
      // Only set JavaScript mode on mobile platforms
      if (!kIsWeb) {
        _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
      }

      // Only set navigation delegate on mobile platforms
      if (!kIsWeb) {
        _controller!.setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading progress if needed
            },
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
              _handleNavigationChange(url);
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _error = 'Failed to load payment page: ${error.description}';
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              return _handleNavigationRequest(request);
            },
          ),
        );
      }

      _controller!.loadRequest(Uri.parse(_checkoutUrl!));

      // For web, simulate loading completion after a delay
      if (kIsWeb) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize payment page: $e';
      });
    }
  }

  void _reloadWebView() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isQRPayment) {
        // For QR payment, cancel existing timer and refresh the order data
        _countdownTimer?.cancel();
        _fetchOrderAndInitializePayment();
      } else if (kIsWeb) {
        // On web, reinitialize the WebView instead of reload
        if (_checkoutUrl != null) {
          _initializeWebView();
        } else {
          _fetchOrderAndInitializePayment();
        }
      } else {
        // On mobile platforms, use the reload method
        _controller?.reload();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to reload payment page: $e';
      });
    }
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final url = request.url.toLowerCase();

    // Handle success/failure URLs
    if (url.contains('success') || url.contains('payment-success')) {
      _handlePaymentSuccess();
      return NavigationDecision.prevent;
    } else if (url.contains('failed') ||
        url.contains('error') ||
        url.contains('cancel')) {
      _handlePaymentFailure();
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleNavigationChange(String url) {
    final lowerUrl = url.toLowerCase();

    // Check for success/failure in URL changes
    if (lowerUrl.contains('success') || lowerUrl.contains('payment-success')) {
      _handlePaymentSuccess();
    } else if (lowerUrl.contains('failed') || lowerUrl.contains('error')) {
      _handlePaymentFailure();
    }
  }

  void _handlePaymentSuccess() {
    // Get payment method name for the status page
    String paymentMethodName = _getPaymentMethodDisplayName();

    // Navigate to payment status page
    context.go('/payment/$paymentMethodName/success?orderId=${widget.orderId}');
  }

  void _handlePaymentFailure() {
    // Get payment method name for the status page
    String paymentMethodName = _getPaymentMethodDisplayName();

    // Navigate to payment status page
    context.go('/payment/$paymentMethodName/failed?orderId=${widget.orderId}');
  }

  void _handlePaymentCanceled() {
    // Get payment method name for the status page
    String paymentMethodName = _getPaymentMethodDisplayName();

    // Navigate to payment status page
    context.go('/payment/$paymentMethodName/cancel?orderId=${widget.orderId}');
  }

  String _getPaymentMethodDisplayName() {
    if (_orderResponse == null || _orderResponse!.paymentMethod.isEmpty) {
      return 'unknown';
    }

    final method = _orderResponse!.paymentMethod[0].method.toLowerCase();

    // Map payment method codes to display names
    switch (method) {
      case 'qrph_xendit':
      case 'qrph':
        return 'maya'; // Default to maya for QR payments
      case 'gcash':
        return 'gcash';
      case 'card':
      case 'credit_card':
        return 'card';
      case 'cash':
      case 'cod':
        return 'cash';
      case 'paypal':
        return 'paypal';
      default:
        debugPrint('Unknown payment method: $method, using unknown');
        return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to payment updates for this specific order
    ref.listen<AsyncValue<PaymentUpdateEvent>>(
      paymentUpdatesProvider,
      (previous, next) {
        next.whenData((event) {
          if (event.orderId == widget.orderId) {
            _handlePaymentEvent(event);
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelConfirmation();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadWebView,
          ),
        ],
      ),
      body: _error != null
          ? _buildErrorView(theme)
          : _isQRPayment
              ? _buildQRPaymentView(theme)
              : _controller != null
                  ? Stack(
                      children: [
                        WebViewWidget(controller: _controller!),
                        if (_isLoading)
                          Container(
                            color: Colors.white.withOpacity(0.8),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading payment page...'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
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
              'Payment Page Error',
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
              onPressed: _reloadWebView,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRPaymentView(ThemeData theme) {
    if (_orderResponse == null || _orderResponse!.paymentMethod.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final paymentMethod = _orderResponse!.paymentMethod[0];
    final qrCodeBody = paymentMethod.paymentProcessor?.qrCodeBody ?? '';

    // Check if payment has expired
    if (_isExpired) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_off,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Expired',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This payment has expired. Please go back and start a new payment.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/order/checkout/${widget.orderId}');
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Start New Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (qrCodeBody.isEmpty) {
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
                'QR Code Not Available',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The QR code for this payment is not available. Please try again or use a different payment method.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _reloadWebView,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Countdown Timer
              if (_remainingTime != null) ...[
                Text(
                  'Complete payment within: ${_formatDuration(_remainingTime!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Amount to Pay
              Text(
                'Amount to Pay',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₱${paymentMethod.totalAmountDue.toStringAsFixed(2)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: qrCodeBody,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (cxt, err) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Invalid QR Code',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Simple Instructions
              Text(
                'Scan this QR code using GCash, Maya, or any QR-enabled banking app',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Order #${widget.orderId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.8),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading payment details...'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmation() {
    if (kIsWeb) {
      // On web, use a full-screen overlay to bypass WebView interference
      _showWebSafeDialog();
    } else {
      // On mobile, use regular dialog
      _showRegularCancelDialog();
    }
  }

  void _showWebSafeDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel Payment',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext context, Animation animation,
          Animation secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cancel Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you sure you want to cancel this payment? Your order will not be processed.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          print(
                              "Continue Payment button pressed"); // Debug print
                          Navigator.of(context).pop();
                        },
                        child: const Text('Continue Payment'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          print("Cancel Payment button pressed"); // Debug print
                          Navigator.of(context).pop();
                          // Navigate to checkout page
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/order/checkout/${widget.orderId}');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel Payment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRegularCancelDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text(
            'Are you sure you want to cancel this payment? Your order will not be processed.'),
        actions: [
          TextButton(
            onPressed: () {
              print("Continue Payment button pressed"); // Debug print
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Continue Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              print("Cancel Payment button pressed"); // Debug print
              Navigator.of(dialogContext).pop();
              // Navigate to checkout page
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/order/checkout/${widget.orderId}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );
  }
}
