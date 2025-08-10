import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/services/order_service.dart';

class WebViewPaymentPage extends StatefulWidget {
  final OrderResponse orderResponse;
  final PaymentMethodResponse paymentMethod;
  final String paymentUrl;

  const WebViewPaymentPage({
    super.key,
    required this.orderResponse,
    required this.paymentMethod,
    required this.paymentUrl,
  });

  @override
  State<WebViewPaymentPage> createState() => _WebViewPaymentPageState();
}

class _WebViewPaymentPageState extends State<WebViewPaymentPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
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
      
      _controller!.loadRequest(Uri.parse(widget.paymentUrl));
      
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
    try {
      if (kIsWeb) {
        // On web, reinitialize the WebView instead of reload
        _initializeWebView();
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
    } else if (url.contains('failed') || url.contains('error') || url.contains('cancel')) {
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
    Navigator.of(context).pop();
    _showPaymentResultDialog(
      isSuccess: true,
      title: 'Payment Successful',
      message: 'Your payment has been processed successfully. Order #${widget.orderResponse.orderNo} is confirmed.',
      icon: Icons.check_circle,
      iconColor: Colors.green,
    );
  }

  void _handlePaymentFailure() {
    Navigator.of(context).pop();
    _showPaymentResultDialog(
      isSuccess: false,
      title: 'Payment Failed',
      message: 'Your payment could not be processed. Please try again or use a different payment method.',
      icon: Icons.error,
      iconColor: Colors.red,
    );
  }

  void _showPaymentResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            if (isSuccess) ...[
              Text('Order: #${widget.orderResponse.orderNo}'),
              Text('Amount: ₱${widget.paymentMethod.totalAmountDue.toStringAsFixed(2)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
              if (isSuccess) {
                // Optionally navigate to order tracking or home
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(isSuccess ? 'View Orders' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _reloadWebView();
            },
          ),
        ],
      ),
      body: _error != null
          ? _buildErrorView(theme)
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
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _reloadWebView();
              },
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

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text('Are you sure you want to cancel this payment? Your order will not be processed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close WebView
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method.toUpperCase()) {
      case 'QRPH':
        return 'GCash / Maya';
      case 'CASH':
        return 'Cash on Delivery';
      case 'CARD':
        return 'Credit/Debit Card';
      default:
        return method;
    }
  }
}
