import 'package:customer_order_app/features/menu/product_customization_page.dart';
import 'package:flutter/material.dart';
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
    redirect: (context, state) {
      final location = state.matchedLocation;
      
      if (kIsWeb) {
        // Web: skip splash, go directly to home
        if (location == '/') {
          return '/home';
        }
      }
      
      // Allow all routes for now - let individual pages handle auth state
      return null;
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

// Helper function to build pages with smooth transitions
Page<dynamic> _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
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
