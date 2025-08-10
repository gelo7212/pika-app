import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'route_utils.dart';

/// Extension on GoRouter context for platform-aware navigation
extension AppNavigation on GoRouterState {
  /// Get route metadata for the current location
  Map<String, String> get routeMetadata => 
      AppRouteUtils.getRouteMetadata(matchedLocation);
  
  /// Get breadcrumbs for the current location
  List<String> get breadcrumbs => 
      AppRouteUtils.getBreadcrumbs(matchedLocation);
  
  /// Get SEO-friendly page title
  String get pageTitle => 
      AppRouteUtils.getPageTitle(matchedLocation);
}

/// Extension on BuildContext for easier navigation
extension AppNavigationContext on GoRouterState {
  /// Navigate to dashboard with platform-specific behavior
  void goToDashboard(GoRouter router) {
    if (kIsWeb) {
      router.goNamed('dashboard');
    } else {
      router.goNamed('dashboard');
    }
  }
  
  /// Navigate to order detail with validation
  void goToOrderDetail(GoRouter router, String orderId) {
    if (orderId.isEmpty) return;
    router.goNamed('orderDetail', pathParameters: {'orderId': orderId});
  }
  
  /// Navigate to menu category with validation
  void goToMenuCategory(GoRouter router, String categoryId) {
    if (categoryId.isEmpty) return;
    router.goNamed('menuCategory', pathParameters: {'categoryId': categoryId});
  }
  
  /// Navigate back with platform-specific behavior
  void goBack(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      // If can't pop, go to home as fallback
      router.go('/home');
    }
  }
}

/// Extension for BuildContext navigation helpers
extension AppNavigationContextHelper on BuildContext {
  /// Safe back navigation that respects GoRouter history
  void safeGoBack() {
    final router = GoRouter.of(this);
    
    // Check if we can pop (there's a previous route in GoRouter history)
    if (router.canPop()) {
      // Use GoRouter's pop to maintain proper browser history
      router.pop();
    } else {
      // Fallback to home if no history (shouldn't happen in normal flow)
      router.go('/home');
    }
  }

  /// Navigate to specific route with GoRouter
  void goToRoute(String route, {Object? extra}) {
    final router = GoRouter.of(this);
    router.go(route, extra: extra);
  }

  /// Push a new route with GoRouter (maintains history)
  Future<T?> pushRoute<T extends Object?>(String route, {Object? extra}) {
    final router = GoRouter.of(this);
    return router.push(route, extra: extra);
  }

  /// Replace current route with GoRouter
  Future<T?> replaceRoute<T extends Object?>(String route, {Object? extra}) {
    final router = GoRouter.of(this);
    return router.replace(route, extra: extra);
  }

  /// Check if we can navigate back
  bool canGoBack() {
    final router = GoRouter.of(this);
    return router.canPop();
  }

  /// Get current location
  String get currentLocation {
    final router = GoRouter.of(this);
    return router.routerDelegate.currentConfiguration.uri.toString();
  }
}

/// Helper class for creating type-safe route parameters
class RouteParams {
  static Map<String, String> orderDetail(String orderId) => 
      {'orderId': orderId};
  
  static Map<String, String> menuCategory(String categoryId) => 
      {'categoryId': categoryId};
}

/// Helper class for query parameters
class QueryParams {
  static Map<String, String> withFilter({
    String? search,
    String? status,
    int? page,
  }) {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (page != null && page > 0) params['page'] = page.toString();
    return params;
  }
  
  static Map<String, String> withPagination({
    int? page,
    int? limit,
  }) {
    final params = <String, String>{};
    if (page != null && page > 0) params['page'] = page.toString();
    if (limit != null && limit > 0) params['limit'] = limit.toString();
    return params;
  }
}
