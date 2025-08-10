import 'package:flutter/material.dart';
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
    
    return isLoggedInAsync.when(
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
    );
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
