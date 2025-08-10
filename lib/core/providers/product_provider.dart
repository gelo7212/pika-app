import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/product_service.dart';
import '../di/service_locator.dart';

// Product state class
class ProductState {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;

  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  ProductState copyWith({
    List<Map<String, dynamic>>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Provider for ProductService
final productServiceProvider = Provider<ProductService>((ref) {
  return serviceLocator<ProductService>();
});

// Provider for products
final productsProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final productService = ref.read(productServiceProvider);
  return ProductNotifier(productService);
});

// StateNotifier for managing product state
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductService _productService;

  ProductNotifier(this._productService) : super(const ProductState());

  Future<void> loadProducts({String? storeId}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final products = await _productService.getProducts(
        storeId: storeId,
        grouped: true,
        availableForSale: true,
      );
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> loadDisplayProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final products = await _productService.getProductsForDisplay();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void clearProducts() {
    state = const ProductState();
  }
}

// Provider that automatically fetches products based on store availability
final menuProductsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, storeId) async {
  final productService = ref.read(productServiceProvider);
  
  if (storeId != null && storeId.isNotEmpty) {
    // Store available, use store-specific endpoint
    return await productService.getProducts(
      storeId: storeId,
      grouped: true,
      availableForSale: true,
    );
  } else {
    // No store, use display endpoint
    return await productService.getProductsForDisplay();
  }
});

// Provider for getting a single product by ID
final productByIdProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, productId) async {
  final productService = ref.read(productServiceProvider);
  return await productService.getProductById(productId);
});
