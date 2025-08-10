import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../models/loyalty_model.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class LoyaltyService {
  final Dio _dio;
  final String _baseUrl;

  LoyaltyService({
    required Dio dio,
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl ??
            ApiConfig.salesUrl; // Use salesUrl as default for loyalty endpoints

  Future<Map<String, String>> _getHeaders() async {
    final tokenService = serviceLocator<TokenServiceInterface>();
    final tokens = await tokenService.getStoredTokens();

    if (tokens == null || tokens.userAccessToken.isEmpty) {
      throw Exception('No authentication token available');
    }

    return {
      ...ApiConfig.getDefaultHeaders(),
      'Authorization': 'Bearer ${tokens.userAccessToken}',
    };
  }

  /// Get all loyalty cards for a specific user
  /// Endpoint: GET /loyalty/user/:userId
  Future<UserLoyaltyData> getUserCards(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/loyalty/user/$userId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle the API response format: { "success": true, "data": [...] }
        if (data['data'] != null) {
          final dataValue = data['data'];

          // Check if data is a List (array of cards)
          if (dataValue is List) {
            final cards = dataValue
                .map((c) => LoyaltyCard.fromJson(c as Map<String, dynamic>))
                .toList();
            return UserLoyaltyData.fromCards(cards);
          }
          // Check if data is a Map (wrapped user loyalty data)
          else if (dataValue is Map<String, dynamic>) {
            return UserLoyaltyData.fromJson(dataValue);
          }
        }
        // Handle legacy format where cards are at root level
        else if (data['cards'] != null) {
          return UserLoyaltyData.fromJson(data as Map<String, dynamic>);
        }
        // Handle case where the entire response is a list of cards
        else if (data is List) {
          final cards = data
              .map((c) => LoyaltyCard.fromJson(c as Map<String, dynamic>))
              .toList();
          return UserLoyaltyData.fromCards(cards);
        }

        // If no cards found, return empty data
        return const UserLoyaltyData(
          cards: [],
          totalAvailablePoints: 0.0,
          totalExpiredPoints: 0.0,
          totalSoonToExpirePoints: 0.0,
        );
      } else {
        throw Exception(
            'Failed to fetch user loyalty cards: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user loyalty cards: $e');
      throw Exception('Failed to fetch user loyalty cards: $e');
    }
  }

  /// Get detailed loyalty card information with transaction history
  /// Endpoint: GET /loyalty/:cardId
  Future<LoyaltyCardHistory> getCardHistory(String cardId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/loyalty/$cardId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle the API response format: { "success": true, "data": {...} }
        if (data['data'] != null) {
          final cardData = data['data'] as Map<String, dynamic>;

          // Create LoyaltyCard from the card data
          final card = LoyaltyCard.fromJson(cardData);

          // Extract transactions from the card data
          final transactionsList = cardData['transactions'] as List? ?? [];
          final transactions = transactionsList
              .map((t) => PointsTransaction.fromJson(t as Map<String, dynamic>))
              .toList();

          return LoyaltyCardHistory(
            card: card,
            transactions: transactions,
          );
        }
        // Handle legacy format
        else if (data['card'] != null) {
          return LoyaltyCardHistory.fromJson(data as Map<String, dynamic>);
        }
        // Handle direct card data format
        else {
          final card = LoyaltyCard.fromJson(data as Map<String, dynamic>);
          final transactionsList = data['transactions'] as List? ?? [];
          final transactions = transactionsList
              .map((t) => PointsTransaction.fromJson(t as Map<String, dynamic>))
              .toList();

          return LoyaltyCardHistory(
            card: card,
            transactions: transactions,
          );
        }
      } else {
        throw Exception('Failed to fetch card history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching card history: $e');
      throw Exception('Failed to fetch card history: $e');
    }
  }

  /// Get redeemable products from the product catalog
  /// Uses existing product service but filters for redeemable items
  Future<List<RedeemableProduct>> getRedeemableProducts({
    String? storeId,
  }) async {
    try {
      final headers = ApiConfig.getDefaultHeaders();
      final Map<String, String> queryParams = {
        'availableForSale': 'true',
      };

      final queryString = Uri(queryParameters: queryParams).query;

      String url;
      if (storeId != null && storeId.isNotEmpty) {
        url = '${ApiConfig.inventoryUrl}/product/public/store/$storeId';
      } else {
        url = '${ApiConfig.inventoryUrl}/product/public/display';
      }

      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }

      final response = await _dio.get(
        url,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> products = [];

        if (data['success'] == true && data['data'] != null) {
          products = data['data'] as List;
        } else if (data is List) {
          products = data;
        }

        // Convert to RedeemableProduct objects and flatten all variants
        final List<RedeemableProduct> redeemableProducts = [];

        for (final product in products) {
          final productMap = product as Map<String, dynamic>;

          // Handle products with variants
          if (productMap['variants'] != null &&
              productMap['variants'] is List) {
            final variants = productMap['variants'] as List;

            for (final variant in variants) {
              final variantMap = variant as Map<String, dynamic>;

              // Check if variant is available for sale
              if (variantMap['availableForSale'] != true) continue;

              // Extract price and convert to points (1 peso = 1 point for redemption)
              final price = (variantMap['price'] as num?)?.toDouble() ?? 0.0;
              if (price <= 0) continue;

              final requiredPoints = price.toInt();

              // Create product name with variant details
              final productName =
                  productMap['name'] as String? ?? 'Unknown Product';
              final variantName = variantMap['name'] as String? ?? '';
              final size = variantMap['size'] as String? ?? '';

              String fullName = productName;
              if (variantName.isNotEmpty && variantName != productName) {
                fullName = variantName;
              }
              if (size.isNotEmpty) {
                fullName += ' ($size)';
              }

              final redeemableProduct = RedeemableProduct(
                id: variantMap['id'] as String? ??
                    variantMap['globalId'] as String? ??
                    '',
                name: fullName,
                description:
                    'Get discount with ${requiredPoints * 0.15} points',
                price: requiredPoints,
                pts: requiredPoints *
                    0.15, // Assuming 1 peso = 1 point, adjust if needed
                imageUrl: variantMap['image'] as String?,
                category: _extractCategory(productMap),
                isAvailable: true,
                metadata: variantMap,
              );

              redeemableProducts.add(redeemableProduct);
            }
          } else {
            // Handle direct product format (fallback)
            final mappedProduct = _mapProductToRedeemable(productMap);
            if (mappedProduct != null) {
              redeemableProducts.add(mappedProduct);
            }
          }
        }

        return redeemableProducts;
      }

      return [];
    } catch (e) {
      print('Error fetching redeemable products: $e');
      return [];
    }
  }

  /// Helper method to map product data to RedeemableProduct (for fallback cases)
  RedeemableProduct? _mapProductToRedeemable(Map<String, dynamic> productData) {
    try {
      // Handle direct product format (fallback)
      int requiredPoints = 0;

      if (productData['redeemPoints'] != null) {
        requiredPoints = (productData['redeemPoints'] as num).toInt();
      } else if (productData['price'] != null) {
        // Calculate points based on price (e.g., 1 peso = 1 point)
        final price = (productData['price'] as num).toDouble();
        requiredPoints = price.toInt();
      }

      // Skip products that don't have point requirements
      if (requiredPoints <= 0) {
        return null;
      }

      return RedeemableProduct(
        id: productData['id'] as String? ?? '',
        name: productData['name'] as String? ?? 'Unknown Product',
        description: productData['description'] as String? ??
            'Get discount with ${requiredPoints * 0.15} points',
        price: requiredPoints,
        pts: requiredPoints *
            0.15, // Assuming 1 peso = 1 point, adjust if needed
        imageUrl: productData['imageUrl'] as String? ??
            productData['image'] as String?,
        category: _extractCategory(productData),
        isAvailable: productData['isAvailable'] as bool? ??
            productData['availableForSale'] as bool? ??
            true,
        metadata: productData,
      );
    } catch (e) {
      print('Error mapping product to redeemable: $e');
      return null;
    }
  }

  /// Helper method to extract category from product data
  String _extractCategory(Map<String, dynamic> productData) {
    if (productData['category'] != null) {
      final category = productData['category'];
      if (category is Map<String, dynamic>) {
        return category['main'] as String? ??
            category['sub'] as String? ??
            'general';
      } else if (category is String) {
        return category;
      }
    }
    return 'general';
  }

  /// Calculate points redemption allowance based on the 15% rule
  ///
  /// Formula: Maximum Points You Can Use = Order Total × 15%
  /// Example: Your order costs ₱100, Maximum points you can redeem = 100 × 15% = 15 points
  ///
  /// Also checks that user has enough available points (balance check)
  static double calculateAllowedRedemption({
    double? orderTotal,
    required double availablePoints,
  }) {
    // If no order total provided, return available points
    if (orderTotal == null || orderTotal <= 0) {
      return availablePoints.floorToDouble();
    }

    // 15% cap calculation: Maximum Points You Can Use = Order Total × 15%
    final allowedByCap = (orderTotal * 0.15);

    // Balance check - use the minimum of cap allowance and available points
    final allowedPointsToRedeem = math.min(allowedByCap, availablePoints);

    // Return whole numbers only
    return allowedPointsToRedeem.floorToDouble();
  }

  /// Filter redeemable products based on allowed redemption amount
  static List<RedeemableProduct> filterRedeemableProducts({
    required List<RedeemableProduct> products,
    required double allowedPointsToRedeem,
  }) {
    return products
        .where((product) =>
            product.isAvailable &&
            (product.price * 0.15) <= allowedPointsToRedeem.floor())
        .map((product) => RedeemableProduct(
              id: product.id,
              name: product.name,
              description: product.description,
              price: product.price,
              pts: product.price * 0.15,
              imageUrl: product.imageUrl,
              category: product.category,
              isAvailable: product.isAvailable,
              metadata: product.metadata,
            ))
        .where((product) => product.pts <= allowedPointsToRedeem.floor())
        .toList();
  }
}
