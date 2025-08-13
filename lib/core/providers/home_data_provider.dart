import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_data_model.dart';
import '../services/home_data_service.dart';
import 'discount_provider.dart';
// import '../di/service_locator.dart'; // Will be used when service locator integration is needed

// Provider for home data service
final homeDataServiceProvider = Provider<HomeDataServiceInterface>((ref) {
  return HomeDataService(); // Will inject HttpClient when API is ready
});

// Provider for home page data
final homePageDataProvider = FutureProvider<HomePageData>((ref) async {
  final homeDataService = ref.read(homeDataServiceProvider);
  return homeDataService.getHomePageData();
});

// Individual providers for each section (for granular updates)
final categoriesProvider = Provider<List<CategoryItem>>((ref) {
  final homeDataAsync = ref.watch(homePageDataProvider);
  return homeDataAsync.when(
    data: (data) => data.categories,
    loading: () => [],
    error: (_, __) => [],
  );
});

final featuredItemsProvider = Provider<List<FeaturedItem>>((ref) {
  final homeDataAsync = ref.watch(homePageDataProvider);
  return homeDataAsync.when(
    data: (data) => data.featuredItems,
    loading: () => [],
    error: (_, __) => [],
  );
});

final specialOffersProvider = Provider<List<SpecialOffer>>((ref) {
  final discountsAsync = ref.watch(discountsProvider);
  return discountsAsync.when(
    data: (discounts) => discounts
        .where((discount) => discount.isActive) // Only show active discounts
        .take(3) // Limit to 3 special offers
        .map((discount) => SpecialOffer.fromDiscount(discount))
        .toList(),
    loading: () => [],
    error: (_, __) => [], // Fall back to empty list on error
  );
});

final advertisementsProvider = Provider<List<Advertisement>>((ref) {
  final homeDataAsync = ref.watch(homePageDataProvider);
  return homeDataAsync.when(
    data: (data) => data.advertisements,
    loading: () => [],
    error: (_, __) => [],
  );
});
