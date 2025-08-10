import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

/// Routing utilities for web and mobile platform optimization
class AppRouteUtils {
  /// Get the appropriate transition for the current platform
  static Page<T> getPageTransition<T extends Object?>(
    GoRouterState state,
    Widget child, {
    String? name,
  }) {
    if (kIsWeb) {
      // Use NoTransitionPage for web to avoid unnecessary animations
      return NoTransitionPage<T>(
        key: state.pageKey,
        name: name,
        child: child,
      );
    } else {
      // Use MaterialPage for mobile with proper transitions
      return MaterialPage<T>(
        key: state.pageKey,
        name: name,
        child: child,
      );
    }
  }

  /// Check if the current route should use shell navigation
  static bool shouldUseShellNavigation(String location) {
    final protectedRoutes = [
      '/dashboard',
      '/menu',
      '/orders',
      '/profile',
      '/settings',
    ];
    
    return protectedRoutes.any((route) => location.startsWith(route));
  }

  /// Get web-friendly breadcrumb navigation
  static List<String> getBreadcrumbs(String location) {
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();
    final breadcrumbs = <String>[];
    
    if (segments.isEmpty) return ['Home'];
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      // Convert route segments to readable names
      switch (segment) {
        case 'dashboard':
          breadcrumbs.add('Dashboard');
          break;
        case 'menu':
          breadcrumbs.add('Menu');
          break;
        case 'orders':
          breadcrumbs.add('Orders');
          break;
        case 'profile':
          breadcrumbs.add('Profile');
          break;
        case 'settings':
          breadcrumbs.add('Settings');
          break;
        case 'account':
          breadcrumbs.add('Account');
          break;
        case 'notifications':
          breadcrumbs.add('Notifications');
          break;
        default:
          // For dynamic segments (like IDs), show them as-is
          breadcrumbs.add(segment);
          break;
      }
    }
    
    return breadcrumbs;
  }

  /// Generate SEO-friendly page titles for web
  static String getPageTitle(String location) {
    final breadcrumbs = getBreadcrumbs(location);
    if (breadcrumbs.isEmpty) return 'Pika - ESBI Delivery';

    return '${breadcrumbs.join(' > ')} | Pika - ESBI Delivery';
  }

  /// Check if route requires authentication
  static bool requiresAuth(String location) {
    final publicRoutes = ['/', '/login'];
    return !publicRoutes.contains(location);
  }

  /// Get the default route for each platform
  static String getDefaultRoute() {
    return kIsWeb ? '/dashboard' : '/';
  }

  /// Handle deep linking for mobile and direct URL access for web
  static String? handleDeepLink(String location) {
    // For mobile, you might want to handle deep links differently
    if (!kIsWeb) {
      // On mobile, always go through splash for proper initialization
      if (location != '/' && location != '/login') {
        // Store the intended destination and redirect to splash
        // You can implement a mechanism to navigate to the stored location after auth
        return '/';
      }
    }
    
    return null; // No redirect needed
  }

  /// Get route-specific metadata for analytics or SEO
  static Map<String, String> getRouteMetadata(String location) {
    final metadata = <String, String>{
      'route': location,
      'platform': kIsWeb ? 'web' : 'mobile',
      'title': getPageTitle(location),
    };

    // Add route-specific metadata
    if (location.startsWith('/orders/')) {
      final orderId = location.split('/').last;
      metadata['orderId'] = orderId;
      metadata['section'] = 'orders';
    } else if (location.startsWith('/menu/category/')) {
      final categoryId = location.split('/').last;
      metadata['categoryId'] = categoryId;
      metadata['section'] = 'menu';
    }

    return metadata;
  }
}

/// Route constants for better maintainability
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String menu = '/menu';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String settings = '/settings';
  
  // Nested routes
  static const String accountSettings = '/settings/account';
  static const String notificationSettings = '/settings/notifications';
  
  // Dynamic routes
  static String orderDetail(String orderId) => '/orders/$orderId';
  static String menuCategory(String categoryId) => '/menu/category/$categoryId';
}
