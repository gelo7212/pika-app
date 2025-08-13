import 'package:customer_order_app/features/menu/product_customization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/main/main_layout.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/menu/menu_page.dart';
import '../../features/menu/cart_page.dart';
import '../../features/orders/order_history_page.dart';
import '../../features/orders/order_tracking_page.dart';
import '../../features/loyalty/loyalty_page.dart';
import '../../features/support/support_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/address/pages/address_management_page.dart';
import '../../features/checkout/pages/order_summary_page.dart';
import '../../features/checkout/pages/payment_page.dart';
import '../../features/checkout/payment_status/payment_status_page.dart';
import '../../features/ai_assist/ai_assist_page.dart';
import '../di/service_locator.dart';
import '../interfaces/auth_interface.dart';

// Auth guard for protected routes
Future<bool> _requiresAuth(String location) async {
  // Routes that don't require authentication
  final publicRoutes = ['/', '/login', '/home'];
  
  if (publicRoutes.contains(location)) {
    return false;
  }
  
  // All other routes require authentication
  return true;
}

// Check if user is authenticated with token validation
Future<bool> _isUserAuthenticated() async {
  try {
    final authService = serviceLocator<AuthInterface>();
    // Validate and refresh token if needed
    final isValid = await authService.validateAndRefreshToken();
    return isValid;
  } catch (e) {
    debugPrint('Auth validation error: $e');
    return false;
  }
}

// Router configuration with proper page transitions
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: kIsWeb ? '/home' : '/',
    debugLogDiagnostics: true, // Enable for debugging navigation issues
    routes: [
      // Auth routes (outside main layout)
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // Main app routes (with bottom navigation)
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const HomePage(),
            ),
          ),
        ],
      ),
      
      // Standalone pages (without bottom navigation)
      GoRoute(
        path: '/ai-assist',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const AIAssistPage(),
        ),
      ),
      GoRoute(
        path: '/addresses',
        pageBuilder: (context, state) {
          return _buildPageWithTransition(
            context,
            state,
            const AddressManagementPage(),
          );
        },
      ),
      GoRoute(
        path: '/menu',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          MenuPage(
            categoryFilter: state.uri.queryParameters['category'],
            itemId: state.uri.queryParameters['item'],
          ),
        ),
      ),
      GoRoute(
        path: '/cart',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const CartPage(),
        ),
      ),
      GoRoute(
        path: '/product-customization',
        pageBuilder: (context, state) {
          final productData = state.extra as Map<String, dynamic>?;
          if (productData == null) {
            // Redirect to menu if no product data
            return _buildPageWithTransition(context, state, const MenuPage());
          }
          return _buildPageWithTransition(
            context,
            state,
            ProductCustomizationPage(
              product: productData['product'] as Map<String, dynamic>,
              isBestSeller: productData['isBestSeller'] as bool? ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/loyalty',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const LoyaltyPage(),
        ),
      ),
      GoRoute(
        path: '/order-history',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const OrderHistoryPage(),
        ),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const SupportPage(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          const ProfilePage(),
        ),
      ),
      // Order checkout route
      GoRoute(
        path: '/order/checkout/:orderId',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _buildPageWithTransition(
            context,
            state,
            OrderSummaryPage.fromOrderId(orderId: orderId),
          );
        },
      ),
      // Payment page route
      GoRoute(
        path: '/order/checkout/:orderId/payment',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _buildPageWithTransition(
            context,
            state,
            PaymentPage(orderId: orderId),
          );
        },
      ),
      // Payment status page route
      GoRoute(
        path: '/payment/:paymentMethod/:status',
        pageBuilder: (context, state) {
          final paymentMethod = state.pathParameters['paymentMethod']!;
          final status = state.pathParameters['status']!;
          final orderId = state.uri.queryParameters['orderId'];
          return _buildPageWithTransition(
            context,
            state,
            PaymentStatusPage(
              paymentMethod: paymentMethod,
              status: status,
              orderId: orderId,
            ),
          );
        },
      ),
      // Order tracking page route
      GoRoute(
        path: '/order/tracking/:orderId',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _buildPageWithTransition(
            context,
            state,
            OrderTrackingPage(orderId: orderId),
          );
        },
      ),
    ],
    redirect: (context, state) async {
      final location = state.matchedLocation;
      
      // Handle web initial route
      if (kIsWeb && location == '/') {
        return '/home';
      }
      
      // Check if route requires authentication
      final requiresAuth = await _requiresAuth(location);
      
      if (requiresAuth) {
        // Check if user is authenticated with token validation
        final isAuthenticated = await _isUserAuthenticated();
        
        if (!isAuthenticated) {
          // Store intended location for redirect after login
          if (location != '/login') {
            return '/login?redirect=${Uri.encodeComponent(location)}';
          }
          return '/login';
        }
      }
      
      return null; // No redirect needed
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Helper function to build pages with smooth transitions and proper back handling
Page<dynamic> _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: _BackButtonHandler(
      currentLocation: state.matchedLocation,
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Enhanced slide transition with scale effect
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      var slideAnimation = Tween(
        begin: begin,
        end: end,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: curve,
        ),
      );

      var scaleAnimation = Tween(
        begin: 0.95,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: curve,
        ),
      );

      var fadeAnimation = Tween(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        ),
      );

      return SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        ),
      );
    },
  );
}

// Widget to handle back button behavior for standalone pages
class _BackButtonHandler extends StatelessWidget {
  final String currentLocation;
  final Widget child;

  const _BackButtonHandler({
    required this.currentLocation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Only wrap standalone pages (not those in MainLayout)
    final standalonePages = [
      '/ai-assist',
      '/addresses',
      '/menu',
      '/cart',
      '/product-customization',
      '/loyalty',
      '/order-history',
      '/support',
      '/profile',
    ];

    final isCheckoutOrPayment = currentLocation.startsWith('/order/') || 
                               currentLocation.startsWith('/payment/');

    if (standalonePages.contains(currentLocation) || isCheckoutOrPayment) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleStandalonePageBack(context, currentLocation);
        },
        child: child,
      );
    }

    return child;
  }

  Future<void> _handleStandalonePageBack(BuildContext context, String location) async {
    final router = GoRouter.of(context);

    switch (location) {
      case '/menu':
      case '/cart':
      case '/loyalty':
      case '/order-history':
      case '/support':
      case '/profile':
        // Go back to home for main pages
        context.go('/home');
        break;
      case '/ai-assist':
      case '/addresses':
        // Try to go back or go to home
        if (router.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        break;
      case '/product-customization':
        // Go back to menu
        context.go('/menu');
        break;
      default:
        // For checkout, payment, and other deep pages
        if (location.startsWith('/order/') || location.startsWith('/payment/')) {
          if (router.canPop()) {
            context.pop();
          } else {
            context.go('/order-history');
          }
        } else {
          if (router.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
        break;
    }
  }
}
