import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    
    return PopScope(
      canPop: false, // Always prevent default back button behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Handle back button navigation properly
        await _handleBackNavigation(context, currentLocation);
      },
      child: isLoggedInAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            title: Text(_getPageTitle(currentLocation)),
            automaticallyImplyLeading: false,
          ),
          body: child,
        ),
        error: (error, stack) => Scaffold(
          body: child, // Show content without navigation when auth check fails
        ),
        data: (isLoggedIn) => Scaffold(
          appBar: isLoggedIn ? AppBar(
            title: Text(_getPageTitle(currentLocation)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.person),
                tooltip: 'Profile',
              ),
            ],
          ) : null, // No app bar when not logged in
          body: child,
          bottomNavigationBar: isLoggedIn ? _buildBottomNavigation(context, currentLocation) : null,
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation(BuildContext context, String currentLocation) async {
    // Get the router to check navigation history
    final router = GoRouter.of(context);
    
    // Handle back button navigation based on current location
    switch (currentLocation) {
      case '/home':
        // On home page, show exit confirmation dialog
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit) {
          // Exit the app
          SystemNavigator.pop();
        }
        break;
      case '/menu':
      case '/loyalty': 
      case '/order-history':
      case '/support':
        // Go back to home for main navigation pages
        context.go('/home');
        break;
      case '/profile':
        // Go back to home from profile
        context.go('/home');
        break;
      case '/cart':
      case '/ai-assist':
      case '/addresses':
        // For standalone pages, try to go back or go to home
        if (router.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        break;
      case '/product-customization':
        // Go back to menu from product customization
        context.go('/menu');
        break;
      default:
        // For checkout, payment, and other deep pages
        if (currentLocation.startsWith('/order/') || 
            currentLocation.startsWith('/payment/')) {
          // For order-related pages, try to pop or go to order history
          if (router.canPop()) {
            context.pop();
          } else {
            context.go('/order-history');
          }
        } else {
          // For other pages, try to go back or go to home
          if (router.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
        break;
    }
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    ) ?? false;
  }

  String _getPageTitle(String location) {
    switch (location) {
      case '/home':
        return 'Home';
      case '/menu':
        return 'Menu';
      case '/loyalty':
        return 'Loyalty Card';
      case '/order-history':
        return 'Order History';
      case '/support':
        return 'Support';
      case '/profile':
        return 'Profile';
      default:
        return 'Pika - ESBI Delivery';
    }
  }

  Widget _buildBottomNavigation(BuildContext context, String currentLocation) {
    final items = [
      {'route': '/home', 'icon': Icons.home, 'label': 'Home'},
      {'route': '/menu', 'icon': Icons.restaurant_menu, 'label': 'Menu'},
      {'route': '/loyalty', 'icon': Icons.card_membership, 'label': 'Loyalty'},
      {'route': '/order-history', 'icon': Icons.history, 'label': 'Orders'},
      {'route': '/support', 'icon': Icons.help, 'label': 'Support'},
    ];

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _getCurrentIndex(currentLocation),
      onTap: (index) {
        final route = items[index]['route'] as String;
        context.go(route);
      },
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon'] as IconData),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  int _getCurrentIndex(String location) {
    switch (location) {
      case '/home':
        return 0;
      case '/menu':
        return 1;
      case '/loyalty':
        return 2;
      case '/order-history':
        return 3;
      case '/support':
        return 4;
      default:
        return 0;
    }
  }
}
