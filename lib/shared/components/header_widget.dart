// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../core/providers/navigation_provider.dart';

// class HeaderWidget extends ConsumerWidget {
//   final bool showBackButton;
//   final VoidCallback? onBackPressed;
//   final String? title;
//   final List<Widget>? actions;

//   const HeaderWidget({
//     super.key,
//     this.showBackButton = false,
//     this.onBackPressed,
//     this.title,
//     this.actions,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final navigationState = ref.watch(navigationProvider);
//     final isDesktop = MediaQuery.of(context).size.width >= 768;

//     return Container(
//       height: kToolbarHeight,
//       decoration: BoxDecoration(
//         color: Theme.of(context).primaryColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             offset: const Offset(0, 2),
//             blurRadius: 4,
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         child: Row(
//           children: [
//             // Left side
//             if (showBackButton)
//               IconButton(
//                 icon: const Icon(Icons.arrow_back, color: Colors.white),
//                 onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
//               )
//             else if (isDesktop)
//               IconButton(
//                 icon: const Icon(Icons.menu, color: Colors.white),
//                 onPressed: () => ref.read(navigationProvider.notifier).toggleSidebar(),
//               )
//             else
//               IconButton(
//                 icon: const Icon(Icons.menu, color: Colors.white),
//                 onPressed: () => ref.read(navigationProvider.notifier).showSidebar(),
//               ),

//             const SizedBox(width: 8),

//             // Title
//             Expanded(
//               child: Text(
//                 title ?? _getPageTitle(navigationState.currentPath),
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),

//             // Actions
//             if (actions != null) ...actions!,

//             // Search button
//             IconButton(
//               icon: const Icon(Icons.search, color: Colors.white),
//               onPressed: () => _showSearch(context),
//             ),

//             // Notifications
//             IconButton(
//               icon: Badge(
//                 label: const Text('3'),
//                 child: const Icon(Icons.notifications, color: Colors.white),
//               ),
//               onPressed: () => _showNotifications(context),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _getPageTitle(String path) {
//     switch (path) {
//       case '/dashboard':
//         return 'Dashboard';
//       case '/menu':
//         return 'Menu';
//       case '/orders':
//         return 'Orders';
//       case '/profile':
//         return 'Profile';
//       case '/settings':
//         return 'Settings';
//       default:
//         if (path.startsWith('/orders/')) {
//           return 'Order Details';
//         }
//         return 'Customer Order App';
//     }
//   }

//   void _showSearch(BuildContext context) {
//     showSearch(
//       context: context,
//       delegate: _SearchDelegate(),
//     );
//   }

//   void _showNotifications(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Notifications'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(Icons.receipt_long),
//               title: Text('New order received'),
//               subtitle: Text('Order #1234 - 2 items'),
//             ),
//             ListTile(
//               leading: Icon(Icons.check_circle),
//               title: Text('Order completed'),
//               subtitle: Text('Order #1233 has been delivered'),
//             ),
//             ListTile(
//               leading: Icon(Icons.local_offer),
//               title: Text('Special offer'),
//               subtitle: Text('20% off on combo meals'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SearchDelegate extends SearchDelegate<String> {
//   @override
//   List<Widget> buildActions(BuildContext context) {
//     return [
//       IconButton(
//         icon: const Icon(Icons.clear),
//         onPressed: () => query = '',
//       ),
//     ];
//   }

//   @override
//   Widget buildLeading(BuildContext context) {
//     return IconButton(
//       icon: const Icon(Icons.arrow_back),
//       onPressed: () => close(context, ''),
//     );
//   }

//   @override
//   Widget buildResults(BuildContext context) {
//     // Implement search results
//     return ListView(
//       children: [
//         ListTile(
//           title: Text('Search results for: "$query"'),
//           subtitle: const Text('No results found'),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget buildSuggestions(BuildContext context) {
//     final suggestions = [
//       'Pizza',
//       'Burger',
//       'Pasta',
//       'Salad',
//       'Drinks',
//     ].where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();

//     return ListView.builder(
//       itemCount: suggestions.length,
//       itemBuilder: (context, index) {
//         return ListTile(
//           leading: const Icon(Icons.search),
//           title: Text(suggestions[index]),
//           onTap: () {
//             query = suggestions[index];
//             showResults(context);
//           },
//         );
//       },
//     );
//   }
// }
