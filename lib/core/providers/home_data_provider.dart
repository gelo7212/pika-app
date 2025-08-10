import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_data_model.dart';
import '../services/home_data_service.dart';
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
  final homeDataAsync = ref.watch(homePageDataProvider);
  return homeDataAsync.when(
    data: (data) => data.specialOffers,
    loading: () => [],
    error: (_, __) => [],
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
