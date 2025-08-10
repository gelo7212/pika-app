import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/components/custom_app_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/addon_provider.dart';
import '../../core/providers/cart_provider.dart';

class ProductCustomizationPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final bool isBestSeller;
  final String? cartId; // Add cartId for editing existing cart items
  final CartItem? existingCartItem; // Add existing cart item for editing

  const ProductCustomizationPage({
    super.key,
    required this.product,
    this.isBestSeller = false,
    this.cartId,
    this.existingCartItem,
  });

  @override
  ConsumerState<ProductCustomizationPage> createState() => _ProductCustomizationPageState();
}

class _ProductCustomizationPageState extends ConsumerState<ProductCustomizationPage> {
  Map<String, dynamic>? selectedVariant;
  int quantity = 1;
  Map<String, int> selectedAddons = {}; // Map of addon ID to quantity

  @override
  void initState() {
    super.initState();
    // Set the first variant as default selection
    final variants = widget.product['variants'] as List<dynamic>? ?? [];
    if (variants.isNotEmpty) {
      selectedVariant = variants[0] as Map<String, dynamic>;
    }
    
    // If editing existing cart item, initialize with existing values
    if (widget.existingCartItem != null) {
      final existingItem = widget.existingCartItem!;
      selectedVariant = existingItem.variant;
      quantity = existingItem.quantity;
      // Convert List<Addon> to Map<String, int> using addonId as key
      selectedAddons = {};
      for (final addon in existingItem.addons) {
        if (addon.addonId.isNotEmpty) {
          selectedAddons[addon.addonId] = addon.qty;
        }
      }
    }
  }

  // Helper method to check if addons should be shown for this product category
  bool _shouldShowAddons(Map<String, dynamic>? category) {
    if (category == null) return false;
    
    final categoryMain = category['main']?.toString().toLowerCase() ?? '';
    final validCategories = ['coffee', 'non coffee', 'frappe', 'fruity blend'];
    
    return validCategories.contains(categoryMain);
  }

  // Helper method to calculate addon total
  double _calculateAddonTotal(List<Map<String, dynamic>> addons) {
    double total = 0.0;
    for (final entry in selectedAddons.entries) {
      final addonId = entry.key;
      final addonQuantity = entry.value;
      
      final addon = addons.firstWhere(
        (addon) => addon['_id'] == addonId,
        orElse: () => {},
      );
      
      if (addon.isNotEmpty) {
        final price = addon['price']?.toDouble() ?? 0.0;
        total += price * addonQuantity;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productName = widget.product['name'] ?? 'Unknown Product';
    final variants = widget.product['variants'] as List<dynamic>? ?? [];
    final category = widget.product['category'] as Map<String, dynamic>?;
    
    // Get image from selected variant or find first available image
    String productImage = '';
    if (selectedVariant != null) {
      productImage = selectedVariant!['image']?.toString() ?? '';
    }
    
    if (productImage.isEmpty && variants.isNotEmpty) {
      for (final variant in variants) {
        final variantImage = variant['image']?.toString() ?? '';
        if (variantImage.isNotEmpty) {
          productImage = variantImage;
          break;
        }
      }
    }

    final currentPrice = selectedVariant?['price']?.toDouble() ?? 0.0;
    
    // Get addons for calculating total
    final addonsAsync = ref.watch(addonsByCategoryProvider(category?['main']));
    final addonTotal = addonsAsync.when(
      data: (addons) => _calculateAddonTotal(addons),
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
    
    final totalPrice = (currentPrice + addonTotal) * quantity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: widget.cartId != null ? 'Edit Item' : 'Customize',
      ),
      body: Column(
        children: [
          // Product Image Section
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
            ),
            child: productImage.isNotEmpty
                ? Image.network(
                    productImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.restaurant_outlined,
                          size: 64,
                          color: theme.textSecondary,
                        ),
                      );
                    },
                  )
                : Center(
                    child: Icon(
                      Icons.restaurant_outlined,
                      size: 64,
                      color: theme.textSecondary,
                    ),
                  ),
          ),

          // Scrollable Content Section
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Category
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (category != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                category['main'] ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.isBestSeller)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Best Seller',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Product Description
                  if (widget.product['description'] != null && 
                      widget.product['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        widget.product['description'].toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Variants Section
                  if (variants.isNotEmpty) ...[
                    Text(
                      'Options',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...variants.asMap().entries.map((entry) {
                      final index = entry.key;
                      final variant = entry.value as Map<String, dynamic>;
                      final isSelected = selectedVariant == variant;
                      final variantName = variant['name'] ?? '';
                      final variantSize = variant['size'] ?? '';
                      final variantPrice = variant['price']?.toDouble() ?? 0.0;
                      final isAvailable = variant['availableForSale'] ?? true;

                      return Container(
                        margin: EdgeInsets.only(bottom: index < variants.length - 1 ? 8 : 0),
                        child: InkWell(
                          onTap: isAvailable ? () {
                            setState(() {
                              selectedVariant = variant;
                            });
                          } : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected 
                                    ? theme.colorScheme.primary
                                    : theme.borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Radio button
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected 
                                          ? theme.colorScheme.primary
                                          : theme.textSecondary,
                                      width: 2,
                                    ),
                                    color: isSelected 
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Variant details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$variantName${variantSize.isNotEmpty ? ' ($variantSize)' : ''}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: isAvailable 
                                              ? theme.textPrimary
                                              : theme.textSecondary,
                                        ),
                                      ),
                                      if (!isAvailable)
                                        Text(
                                          'Not Available',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // Price
                                Text(
                                  '₱${variantPrice.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isAvailable 
                                        ? theme.colorScheme.primary
                                        : theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ] else ...[
                    Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const Text('No options available for this product'),
                    ),
                  ],

                  // Addons Section - only show for valid categories
                  if (_shouldShowAddons(category)) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Add-ons',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, child) {
                        final addonsAsync = ref.watch(addonsByCategoryProvider(category?['main']));
                        
                        return addonsAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stack) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'Failed to load add-ons',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          data: (addons) {
                            if (addons.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text('No add-ons available'),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: addons.asMap().entries.map((entry) {
                                final index = entry.key;
                                final addon = entry.value;
                                final addonId = addon['_id'] ?? '';
                                final addonName = addon['name'] ?? '';
                                final addonPrice = addon['price']?.toDouble() ?? 0.0;
                                final selectedQuantity = selectedAddons[addonId] ?? 0;

                                return Container(
                                  margin: EdgeInsets.only(bottom: index < addons.length - 1 ? 8 : 0),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: selectedQuantity > 0 
                                        ? theme.colorScheme.primary.withOpacity(0.1)
                                        : Colors.white,
                                    border: Border.all(
                                      color: selectedQuantity > 0 
                                          ? theme.colorScheme.primary
                                          : theme.borderColor,
                                      width: selectedQuantity > 0 ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              addonName,
                                              style: theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₱${addonPrice.toStringAsFixed(2)}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Quantity controls
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: selectedQuantity > 0 ? () {
                                              setState(() {
                                                if (selectedQuantity == 1) {
                                                  selectedAddons.remove(addonId);
                                                } else {
                                                  selectedAddons[addonId] = selectedQuantity - 1;
                                                }
                                              });
                                            } : null,
                                            icon: const Icon(Icons.remove),
                                            iconSize: 20,
                                          ),
                                          Container(
                                            width: 30,
                                            alignment: Alignment.center,
                                            child: Text(
                                              selectedQuantity.toString(),
                                              style: theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                selectedAddons[addonId] = selectedQuantity + 1;
                                              });
                                            },
                                            icon: const Icon(Icons.add),
                                            iconSize: 20,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 100), // Bottom padding for scroll clearance
                ],
              ),
            ),
          ),

          // Fixed Bottom Section with Quantity and Add to Cart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: theme.borderColor, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Quantity',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: quantity > 1 ? () {
                                setState(() {
                                  quantity--;
                                });
                              } : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 20,
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                quantity.toString(),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  quantity++;
                                });
                              },
                              icon: const Icon(Icons.add),
                              iconSize: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: selectedVariant != null ? () {
                        _addToCart();
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '${widget.cartId != null ? 'Update Cart' : 'Add to Cart'} - ₱${totalPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart() async {
    if (selectedVariant == null) return;

    final cartNotifier = ref.read(cartProvider.notifier);
    final isEditMode = widget.cartId != null;
    
    // Get addon metadata for proper ID and price storage
    final addonsAsync = ref.read(addonsByCategoryProvider(widget.product['category']?['main']));
    List<Map<String, dynamic>> addonMetadata = [];
    addonsAsync.when(
      data: (addons) => addonMetadata = addons,
      loading: () => addonMetadata = [],
      error: (_, __) => addonMetadata = [],
    );

    try {
      if (isEditMode) {
        // Update existing cart item
        await cartNotifier.updateItem(
          cartId: widget.cartId!,
          product: widget.product,
          variant: selectedVariant!,
          quantity: quantity,
          addons: selectedAddons,
          isBestSeller: widget.isBestSeller,
          addonMetadata: addonMetadata,
        );
      } else {
        // Add new item to cart
        await cartNotifier.addItem(
          product: widget.product,
          variant: selectedVariant!,
          quantity: quantity,
          addons: selectedAddons,
          isBestSeller: widget.isBestSeller,
          addonMetadata: addonMetadata,
        );
      }

      // Build addon summary for display
      String addonSummary = '';
      if (selectedAddons.isNotEmpty && addonMetadata.isNotEmpty) {
        final addonNames = selectedAddons.entries
            .map((entry) {
              final addonData = addonMetadata.firstWhere(
                (addon) => addon['_id'] == entry.key,
                orElse: () => {'name': 'Unknown Addon'},
              );
              return '${entry.value}x ${addonData['name']}';
            })
            .join(', ');
        addonSummary = ' with $addonNames';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isEditMode ? 'Updated' : 'Added'} $quantity x ${selectedVariant!['name']}$addonSummary ${isEditMode ? 'in' : 'to'} cart',
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to menu
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isEditMode ? 'update' : 'add'} item ${isEditMode ? 'in' : 'to'} cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
