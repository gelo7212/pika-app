import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/addon_model.dart';
import 'dart:convert';

// Cart item model
class CartItem {
  final String id;
  final Map<String, dynamic> product;
  final Map<String, dynamic> variant;
  final int quantity;
  final List<Addon> addons;
  final bool isBestSeller;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.product,
    required this.variant,
    required this.quantity,
    required this.addons,
    required this.isBestSeller,
    required this.addedAt,
  });

  // Calculate base price (variant price * quantity)
  double get basePrice {
    final variantPrice = variant['price']?.toDouble() ?? 0.0;
    return variantPrice * quantity;
  }

  // Calculate addon total
  double get addonTotal {
    double total = 0.0;
    for (final addon in addons) {
      total += addon.price * addon.qty;
    }
    return total * quantity;
  }

  // Total price including addons
  double get totalPrice => basePrice + addonTotal;

  // Get display name
  String get displayName {
    final productName = product['name'] ?? 'Unknown Product';
    final variantName = variant['name'] ?? '';
    final variantSize = variant['size'] ?? '';
    
    String name = productName;
    
    // Only add variant info if it's meaningful and different from product name
    if (variantName.isNotEmpty && variantName != productName) {
      name += ' - $variantName';
    }
    
    // Only add size if it's different from variant name and meaningful
    if (variantSize.isNotEmpty && variantSize != variantName && variantSize.toLowerCase() != 'regular') {
      name += ' ($variantSize)';
    }
    
    return name;
  }

  // Get product image
  String get imageUrl {
    return variant['image']?.toString() ?? product['image']?.toString() ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product,
      'variant': variant,
      'quantity': quantity,
      'addons': addons.map((addon) => addon.toJson()).toList(),
      'isBestSeller': isBestSeller,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  static CartItem fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      product: Map<String, dynamic>.from(json['product']),
      variant: Map<String, dynamic>.from(json['variant']),
      quantity: json['quantity'],
      addons: (json['addons'] as List<dynamic>?)
          ?.map((addonJson) => Addon.fromJson(addonJson))
          .toList() ?? [],
      isBestSeller: json['isBestSeller'] ?? false,
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  CartItem copyWith({
    String? id,
    Map<String, dynamic>? product,
    Map<String, dynamic>? variant,
    int? quantity,
    List<Addon>? addons,
    bool? isBestSeller,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      addons: addons ?? this.addons,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

// Cart state
class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;

  CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  // Calculate total number of items in cart
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  // Calculate total price of all items
  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Check if cart is empty
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Cart provider
class CartNotifier extends StateNotifier<CartState> {
  static const String _storageKey = 'customer_cart';
  static const _storage = FlutterSecureStorage();

  CartNotifier() : super(CartState()) {
    _loadCartFromStorage();
  }

  // Load cart from persistent storage
  Future<void> _loadCartFromStorage() async {
    try {
      state = state.copyWith(isLoading: true);
      final storedCart = await _storage.read(key: _storageKey);
      
      if (storedCart != null) {
        final List<dynamic> cartData = jsonDecode(storedCart);
        final items = cartData.map((item) => CartItem.fromJson(item)).toList();
        state = state.copyWith(items: items, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load cart');
    }
  }

  // Save cart to persistent storage
  Future<void> _saveCartToStorage() async {
    try {
      final cartData = state.items.map((item) => item.toJson()).toList();
      await _storage.write(key: _storageKey, value: jsonEncode(cartData));
    } catch (e) {
      // Handle storage error silently for now
      print('Failed to save cart to storage: $e');
    }
  }

  // Add item to cart
  Future<void> addItem({
    required Map<String, dynamic> product,
    required Map<String, dynamic> variant,
    required int quantity,
    required Map<String, int> addons,
    bool isBestSeller = false,
    List<Map<String, dynamic>>? addonMetadata, // Full addon data with IDs and prices
    String? cartId, // Optional: if provided, this will update the existing cart item
  }) async {
    List<CartItem> updatedItems;
    
    // Convert Map<String, int> addons to List<Addon> using metadata
    final List<Addon> addonList = addons.entries.map((entry) {
      final addonId = entry.key;
      final quantity = entry.value;
      
      // Find addon metadata by ID
      final addonData = addonMetadata?.firstWhere(
        (addon) => addon['_id'] == addonId,
        orElse: () => {},
      );
      
      return Addon(
        addonId: addonId,
        name: addonData?['name'] ?? 'Unknown Addon',
        price: addonData?['price']?.toDouble() ?? 0.0,
        qty: quantity,
      );
    }).toList();
    
    if (cartId != null) {
      // Update existing cart item by cartId
      final existingItemIndex = state.items.indexWhere((item) => item.id == cartId);
      
      if (existingItemIndex >= 0) {
        // Update existing item
        final existingItem = state.items[existingItemIndex];
        final updatedItem = existingItem.copyWith(
          product: product,
          variant: variant,
          quantity: quantity,
          addons: addonList,
          isBestSeller: isBestSeller,
        );
        
        updatedItems = List.from(state.items);
        updatedItems[existingItemIndex] = updatedItem;
      } else {
        // If cartId doesn't exist, treat as new item
        final newItemId = _generateCartItemId(product, variant, addonList);
        final newItem = CartItem(
          id: newItemId,
          product: product,
          variant: variant,
          quantity: quantity,
          addons: addonList,
          isBestSeller: isBestSeller,
          addedAt: DateTime.now(),
        );
        
        updatedItems = [...state.items, newItem];
      }
    } else {
      // Generate unique ID for the cart item
      final itemId = _generateCartItemId(product, variant, addonList);
      
      // Check if item already exists in cart
      final existingItemIndex = state.items.indexWhere((item) => item.id == itemId);
      
      if (existingItemIndex >= 0) {
        // Update existing item quantity
        final existingItem = state.items[existingItemIndex];
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + quantity,
        );
        
        updatedItems = List.from(state.items);
        updatedItems[existingItemIndex] = updatedItem;
      } else {
        // Add new item
        final newItem = CartItem(
          id: itemId,
          product: product,
          variant: variant,
          quantity: quantity,
          addons: addonList,
          isBestSeller: isBestSeller,
          addedAt: DateTime.now(),
        );
        
        updatedItems = [...state.items, newItem];
      }
    }
    
    state = state.copyWith(items: updatedItems);
    await _saveCartToStorage();
  }

  // Update item in cart
  Future<void> updateItem({
    required String cartId,
    required Map<String, dynamic> product,
    required Map<String, dynamic> variant,
    required int quantity,
    required Map<String, int> addons,
    bool isBestSeller = false,
    List<Map<String, dynamic>>? addonMetadata,
  }) async {
    await addItem(
      product: product,
      variant: variant,
      quantity: quantity,
      addons: addons,
      isBestSeller: isBestSeller,
      addonMetadata: addonMetadata,
      cartId: cartId,
    );
  }

  // Remove item from cart
  Future<void> removeItem(String itemId) async {
    final updatedItems = state.items.where((item) => item.id != itemId).toList();
    state = state.copyWith(items: updatedItems);
    await _saveCartToStorage();
  }

  // Update item quantity
  Future<void> updateItemQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(itemId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
    await _saveCartToStorage();
  }

  // Clear entire cart
  Future<void> clearCart() async {
    state = state.copyWith(items: []);
    await _saveCartToStorage();
  }

  // Generate unique ID for cart item based on product, variant, and addons
  String _generateCartItemId(
    Map<String, dynamic> product,
    Map<String, dynamic> variant,
    List<Addon> addons,
  ) {
    final productId = product['_id'] ?? product['id'] ?? '';
    // Use only the variant ID, not the name or size to avoid issues
    final variantId = variant['_id'] ?? variant['id'] ?? '';
    final addonString = addons
        .map((addon) => '${addon.name.replaceAll(' ', '_').replaceAll(',', '-')}:${addon.qty}')
        .join(',');
    
    // Clean the IDs to ensure they don't contain special characters
    final cleanProductId = productId.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanVariantId = variantId.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanAddonString = addonString.replaceAll(RegExp(r'[^a-zA-Z0-9:,_-]'), '');
    
    return '$cleanProductId-$cleanVariantId${cleanAddonString.isNotEmpty ? '-$cleanAddonString' : ''}';
  }

  // Get item by product for editing (navigate to customization page)
  CartItem? getItemById(String itemId) {
    try {
      return state.items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }
}

// Provider instances
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// Helper providers
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.totalItems;
});

final cartTotalPriceProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.totalPrice;
});

final cartIsEmptyProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.isEmpty;
});
