import 'package:customer_order_app/core/models/discount_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/discount_interface.dart';
import '../di/service_locator.dart';

// Provider for the discount service
final discountServiceProvider = Provider<DiscountServiceInterface>((ref) {
  return serviceLocator<DiscountServiceInterface>();
});

// Provider for fetching discounts
final discountsProvider = FutureProvider<List<DiscountModel>>((ref) async {
  final discountService = ref.watch(discountServiceProvider);
  return discountService.fetchDiscounts();
});

// Provider for discount state management
final discountStateProvider = StateNotifierProvider<DiscountStateNotifier, DiscountState>((ref) {
  return DiscountStateNotifier(ref.watch(discountServiceProvider));
});

// State class for discount management
class DiscountState {
  final List<Map<String, dynamic>> discounts;
  final bool isLoading;
  final String? error;

  const DiscountState({
    this.discounts = const [],
    this.isLoading = false,
    this.error,
  });

  DiscountState copyWith({
    List<Map<String, dynamic>>? discounts,
    bool? isLoading,
    String? error,
  }) {
    return DiscountState(
      discounts: discounts ?? this.discounts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// State notifier for discount management
class DiscountStateNotifier extends StateNotifier<DiscountState> {
  final DiscountServiceInterface _discountService;

  DiscountStateNotifier(this._discountService) : super(const DiscountState());

  Future<void> fetchDiscounts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final discountModels = await _discountService.fetchDiscounts();
      final discounts = discountModels.map((d) => d.toJson()).toList();
      state = state.copyWith(
        discounts: discounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const DiscountState();
  }
}
