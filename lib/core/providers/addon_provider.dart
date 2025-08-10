import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../di/service_locator.dart';
import '../interfaces/addon_interface.dart';

// Provider for addon service
final addonServiceProvider = Provider<AddonInterface>((ref) {
  return serviceLocator<AddonInterface>();
});

// Provider for fetching all addons
final addonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final addonService = ref.read(addonServiceProvider);
  return addonService.getAllAddons();
});

// Provider for fetching addons by category (filtered)
final addonsByCategoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, category) async {
  final addons = await ref.read(addonsProvider.future);
  
  if (category == null) return addons;
  
  // Filter addons based on product category
  // For coffee, non coffee, frappe, fruity blend categories
  final validCategories = ['coffee', 'non coffee', 'frappe', 'fruity blend'];
  
  if (validCategories.contains(category.toLowerCase())) {
    // Return all active addons for valid categories
    return addons.where((addon) => addon['status'] == 'active').toList();
  }
  
  // Return empty list for categories that don't support addons
  return [];
});

// Provider for fetching a specific addon by ID
final addonByIdProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final addonService = ref.read(addonServiceProvider);
  return addonService.getAddonById(id);
});
