import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store_model.dart';
import '../services/store_service.dart';
import '../di/service_locator.dart';

// Provider for StoreService
final storeServiceProvider = Provider<StoreService>((ref) {
  return serviceLocator<StoreService>();
});

// Provider for nearest store
final nearestStoreProvider = FutureProvider<({Store? store, bool usedCurrentLocation})>((ref) async {
  final storeService = ref.read(storeServiceProvider);
  return await storeService.getNearestStoreAuto();
});

// Provider for current store (cached)
final currentStoreProvider = StateProvider<Store?>((ref) => null);

// Provider to refresh nearest store
final refreshNearestStoreProvider = StateProvider<int>((ref) => 0);

// Provider that depends on refresh trigger
final nearestStoreWithRefreshProvider = FutureProvider<({Store? store, bool usedCurrentLocation})>((ref) async {
  // Watch the refresh trigger
  ref.watch(refreshNearestStoreProvider);
  
  final storeService = ref.read(storeServiceProvider);
  return await storeService.getNearestStoreAuto();
});
