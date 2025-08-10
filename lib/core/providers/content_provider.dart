// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// /// Content type enum to define what content to render
// enum ContentType {
//   dashboard,
//   menu,
//   orders,
//   profile,
//   orderDetails,
//   menuDetails,
//   custom,
// }

// /// Content state model
// class ContentState {
//   final ContentType type;
//   final Map<String, dynamic> data;
//   final String? title;
//   final Widget? customContent;

//   const ContentState({
//     this.type = ContentType.dashboard,
//     this.data = const {},
//     this.title,
//     this.customContent,
//   });

//   ContentState copyWith({
//     ContentType? type,
//     Map<String, dynamic>? data,
//     String? title,
//     Widget? customContent,
//   }) {
//     return ContentState(
//       type: type ?? this.type,
//       data: data ?? this.data,
//       title: title ?? this.title,
//       customContent: customContent ?? this.customContent,
//     );
//   }
// }

// /// Content state notifier
// class ContentNotifier extends StateNotifier<ContentState> {
//   ContentNotifier() : super(const ContentState());

//   void showDashboard() {
//     state = state.copyWith(
//       type: ContentType.dashboard,
//       title: 'Dashboard',
//       data: {},
//       customContent: null,
//     );
//   }

//   void showMenu({Map<String, dynamic>? filterData}) {
//     state = state.copyWith(
//       type: ContentType.menu,
//       title: 'Menu',
//       data: filterData ?? {},
//       customContent: null,
//     );
//   }

//   void showOrders({Map<String, dynamic>? filterData}) {
//     state = state.copyWith(
//       type: ContentType.orders,
//       title: 'Orders',
//       data: filterData ?? {},
//       customContent: null,
//     );
//   }

//   void showProfile() {
//     state = state.copyWith(
//       type: ContentType.profile,
//       title: 'Profile',
//       data: {},
//       customContent: null,
//     );
//   }

//   void showOrderDetails(String orderId, {Map<String, dynamic>? additionalData}) {
//     state = state.copyWith(
//       type: ContentType.orderDetails,
//       title: 'Order Details',
//       data: {'orderId': orderId, ...?additionalData},
//       customContent: null,
//     );
//   }

//   void showMenuDetails(String itemId, {Map<String, dynamic>? additionalData}) {
//     state = state.copyWith(
//       type: ContentType.menuDetails,
//       title: 'Menu Item',
//       data: {'itemId': itemId, ...?additionalData},
//       customContent: null,
//     );
//   }

//   void showCustomContent(Widget content, {String? title}) {
//     state = state.copyWith(
//       type: ContentType.custom,
//       title: title ?? 'Custom Content',
//       customContent: content,
//       data: {},
//     );
//   }

//   void updateData(Map<String, dynamic> newData) {
//     state = state.copyWith(data: {...state.data, ...newData});
//   }

//   void updateTitle(String title) {
//     state = state.copyWith(title: title);
//   }
// }

// /// Provider for content state
// final contentProvider = StateNotifierProvider<ContentNotifier, ContentState>(
//   (ref) => ContentNotifier(),
// );

// /// Convenience providers
// final currentContentTypeProvider = Provider<ContentType>((ref) {
//   return ref.watch(contentProvider).type;
// });

// final contentDataProvider = Provider<Map<String, dynamic>>((ref) {
//   return ref.watch(contentProvider).data;
// });

// final contentTitleProvider = Provider<String?>((ref) {
//   return ref.watch(contentProvider).title;
// });
