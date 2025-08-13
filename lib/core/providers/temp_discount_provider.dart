import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';

// Temporary discount state for holding selected discount
class TempDiscountState {
  final DiscountModel? selectedDiscount;
  final bool isLoading;
  final String? error;

  const TempDiscountState({
    this.selectedDiscount,
    this.isLoading = false,
    this.error,
  });

  TempDiscountState copyWith({
    DiscountModel? selectedDiscount,
    bool? isLoading,
    String? error,
    bool clearDiscount = false,
  }) {
    return TempDiscountState(
      selectedDiscount: clearDiscount ? null : (selectedDiscount ?? this.selectedDiscount),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasDiscount => selectedDiscount != null;
}

// State notifier for temporary discount management
class TempDiscountNotifier extends StateNotifier<TempDiscountState> {
  TempDiscountNotifier() : super(const TempDiscountState());

  // Select a discount (called when user clicks on special offer)
  void selectDiscount(DiscountModel discount) {
    state = state.copyWith(selectedDiscount: discount);
  }

  // Clear selected discount
  void clearDiscount() {
    state = state.copyWith(clearDiscount: true);
  }

  // Calculate discount amount based on order total
  double calculateDiscountAmount(double orderTotal) {
    if (!state.hasDiscount) return 0.0;

    final discount = state.selectedDiscount!;

    // Check minimum purchase requirement
    if (discount.minPurchaseAmount != null && 
        orderTotal < discount.minPurchaseAmount!) {
      return 0.0;
    }

    // Calculate discount based on type
    switch (discount.type) {
      case DiscountType.percentage:
        return orderTotal * (discount.value / 100);
      case DiscountType.fixed:
        return discount.value;
    }
  }

  // Check if discount is applicable to current order
  bool isDiscountApplicable(double orderTotal, List<String>? productIds) {
    if (!state.hasDiscount) return false;

    final discount = state.selectedDiscount!;

    // Check if discount is active
    if (!discount.isActive) return false;

    // Check date validity
    final now = DateTime.now();
    if (discount.startDate != null && now.isBefore(discount.startDate!)) {
      return false;
    }
    if (discount.endDate != null && now.isAfter(discount.endDate!)) {
      return false;
    }

    // Check minimum purchase amount
    if (discount.minPurchaseAmount != null && 
        orderTotal < discount.minPurchaseAmount!) {
      return false;
    }

    // Check product-specific constraints
    if (discount.productIds != null && 
        discount.productIds!.isNotEmpty && 
        productIds != null) {
      final hasMatchingProduct = discount.productIds!
          .any((discountProductId) => productIds.contains(discountProductId));
      if (!hasMatchingProduct) return false;
    }

    return true;
  }

  // Get discount validation message
  String? getDiscountValidationMessage(double orderTotal) {
    if (!state.hasDiscount) return null;

    final discount = state.selectedDiscount!;

    if (!discount.isActive) {
      return 'This discount is not active';
    }

    final now = DateTime.now();
    if (discount.startDate != null && now.isBefore(discount.startDate!)) {
      return 'This discount is not yet available';
    }
    if (discount.endDate != null && now.isAfter(discount.endDate!)) {
      return 'This discount has expired';
    }

    if (discount.minPurchaseAmount != null && 
        orderTotal < discount.minPurchaseAmount!) {
      return 'Minimum purchase of ₱${discount.minPurchaseAmount!.toStringAsFixed(2)} required';
    }

    return null;
  }
}

// Provider for temporary discount management
final tempDiscountProvider = StateNotifierProvider<TempDiscountNotifier, TempDiscountState>((ref) {
  return TempDiscountNotifier();
});

// Helper providers
final selectedDiscountProvider = Provider<DiscountModel?>((ref) {
  final tempDiscount = ref.watch(tempDiscountProvider);
  return tempDiscount.selectedDiscount;
});

final hasSelectedDiscountProvider = Provider<bool>((ref) {
  final tempDiscount = ref.watch(tempDiscountProvider);
  return tempDiscount.hasDiscount;
});
