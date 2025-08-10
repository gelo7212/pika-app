import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loyalty_model.dart';
import '../services/loyalty_service.dart';
import '../di/service_locator.dart';
import '../interfaces/auth_interface.dart';
import 'auth_provider.dart';
import 'package:dio/dio.dart';

// Loyalty Service Provider
final loyaltyServiceProvider = Provider<LoyaltyService>((ref) {
  return LoyaltyService(
    dio: Dio(),
  );
});

// Current User ID Provider - uses existing auth provider
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  try {
    final authService = serviceLocator<AuthInterface>();
    final token = await authService.getCurrentUserToken();
    if (token != null) {
      final payload = await authService.decodeToken(token);

      debugPrint('Current User Token: ${payload}');
      return payload?.userId; // User ID is in the 'userId' field
    }

    return null;
  } catch (e) {
    return null;
  }
});

// User Loyalty Data Provider
final userLoyaltyDataProvider =
    FutureProvider.family<UserLoyaltyData, String>((ref, userId) async {
  final loyaltyService = ref.read(loyaltyServiceProvider);
  return await loyaltyService.getUserCards(userId);
});

// Loyalty Card History Provider
final loyaltyCardHistoryProvider =
    FutureProvider.family<LoyaltyCardHistory, String>((ref, cardId) async {
  final loyaltyService = ref.read(loyaltyServiceProvider);
  return await loyaltyService.getCardHistory(cardId);
});

// Redeemable Products Provider
final redeemableProductsProvider =
    FutureProvider.family<List<RedeemableProduct>, String?>(
        (ref, storeId) async {
  final loyaltyService = ref.read(loyaltyServiceProvider);
  return await loyaltyService.getRedeemableProducts(storeId: storeId);
});

// Filtered Redeemable Products Provider (based on order total and available points)
final filteredRedeemableProductsProvider =
    Provider.family<AsyncValue<List<RedeemableProduct>>, FilterParams>(
        (ref, params) {
  final redeemableProductsAsync =
      ref.watch(redeemableProductsProvider(params.storeId));

  return redeemableProductsAsync.when(
    data: (products) {
      final allowedPointsToRedeem = LoyaltyService.calculateAllowedRedemption(
        orderTotal: params.orderTotal,
        availablePoints: params.availablePoints,
      );

      final filteredProducts = LoyaltyService.filterRedeemableProducts(
        products: products,
        allowedPointsToRedeem: allowedPointsToRedeem,
      );

      return AsyncValue.data(filteredProducts);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// Helper class for filter parameters
class FilterParams {
  final String? storeId;
  final double orderTotal;
  final double availablePoints;

  const FilterParams({
    this.storeId,
    required this.orderTotal,
    required this.availablePoints,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterParams &&
          runtimeType == other.runtimeType &&
          storeId == other.storeId &&
          orderTotal == other.orderTotal &&
          availablePoints == other.availablePoints;

  @override
  int get hashCode =>
      storeId.hashCode ^ orderTotal.hashCode ^ availablePoints.hashCode;
}
