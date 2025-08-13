import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/providers/discount_provider.dart';
import '../../core/providers/temp_discount_provider.dart';
import '../../core/models/order_model.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/address_model.dart';
import '../../core/models/addon_model.dart';
import '../../core/models/discount_model.dart';
import '../../core/services/order_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/navigation_extensions.dart';
import '../../shared/components/custom_app_bar.dart';
import '../../shared/widgets/set_default_address_banner.dart';
import '../../features/address/pages/address_management_page.dart';
import 'product_customization_page.dart';
import 'widgets/delivery_details_section.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  bool _hasShownPendingOrderModal = false;

  @override
  void initState() {
    super.initState();
    // Auto-populate customer name when cart loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPopulateCustomerName();
    });
  }

  Future<void> _autoPopulateCustomerName() async {
    final deliveryDetails = ref.read(deliveryProvider);
    final deliveryNotifier = ref.read(deliveryProvider.notifier);

    // Only auto-populate if customer name is empty
    if (deliveryDetails.customerName == null ||
        deliveryDetails.customerName!.trim().isEmpty ||
        deliveryDetails.customerName!.trim() == 'Guest Customer') {
      final userProfileAsync = ref.read(userProfileProvider);
      userProfileAsync.when(
        data: (userProfile) {
          String autoName = '';
          if (userProfile.name.trim().isNotEmpty) {
            autoName = userProfile.name.trim();
          }

          // Only auto-fill if we have a real name, not a placeholder
          if (autoName.isNotEmpty) {
            deliveryNotifier.updateCustomerName(autoName);
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    }
  }

  @override
  void dispose() {
    _hasShownPendingOrderModal = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset modal flag when widget updates to allow modal to show again if needed
    _hasShownPendingOrderModal = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final recentPendingOrderAsync =
        ref.watch(recentPendingOrderWithRefreshProvider);

    if (cartState.isLoading) {
      return Scaffold(
        appBar: CustomAppBar(title: 'Cart'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Check for pending order and handle cart logic
    return recentPendingOrderAsync.when(
      loading: () => Scaffold(
        appBar: CustomAppBar(title: 'Cart'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) =>
          _buildCartPage(context, theme, cartState, cartNotifier, ref, null),
      data: (pendingOrder) {
        return _buildCartPage(
            context, theme, cartState, cartNotifier, ref, pendingOrder);
      },
    );
  }

  Widget _buildCartPage(
    BuildContext context,
    ThemeData theme,
    CartState cartState,
    CartNotifier cartNotifier,
    WidgetRef ref,
    OrderResponse? pendingOrder,
  ) {
    // If there's a pending order, check if it's paid before loading to cart
    if (pendingOrder != null &&
        cartState.isEmpty &&
        !_hasShownPendingOrderModal) {
      // Check if the order is already paid
      final isPaid = pendingOrder.paymentMethod.isNotEmpty &&
          pendingOrder.paymentMethod.any((payment) => payment.isPaid == true);

      // Only load to cart if the order is not paid
      if (!isPaid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _hasShownPendingOrderModal = true;
          _loadPendingOrderToCartSilently(ref, pendingOrder);
        });
      }
    }

    // If cart is empty and no pending order (or pending order is paid), show empty cart
    if (cartState.isEmpty &&
        (pendingOrder == null ||
            (pendingOrder.paymentMethod.isNotEmpty &&
                pendingOrder.paymentMethod
                    .any((payment) => payment.isPaid == true)))) {
      return Scaffold(
        appBar: CustomAppBar(title: 'Cart'),
        body: _buildEmptyCart(context, theme),
      );
    }

    // Normal cart flow with pending order binding
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Cart (${cartState.totalItems})',
        actions: [
          TextButton(
            onPressed: () =>
                _showClearCartDialog(context, cartNotifier, pendingOrder),
            child: Text(
              'Clear',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cart Items List
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Cart Items
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: cartState.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return _CartItemCard(
                        item: item,
                        onQuantityChanged: (quantity) async {
                          await cartNotifier.updateItemQuantity(
                              item.id, quantity);
                          // Auto-update pending order if bound
                          if (pendingOrder != null) {
                            _updatePendingOrderFromCart(ref, pendingOrder);
                          }
                        },
                        onRemove: () async {
                          await cartNotifier.removeItem(item.id);
                          // Auto-update pending order if bound
                          if (pendingOrder != null) {
                            _updatePendingOrderFromCart(ref, pendingOrder);
                          }
                        },
                        onEdit: () {
                          _editCartItem(context, item);
                        },
                      );
                    },
                  ),

                  // Address Required/Set Default Address Banner
                  const SetDefaultAddressBanner(),
                  
                  // Address Required Banner for users with no addresses
                  Consumer(
                    builder: (context, ref, child) {
                      final addressesAsync = ref.watch(addressNotifierProvider);
                      
                      return addressesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
                        data: (addresses) {
                          // Only show if no addresses exist
                          if (addresses.isNotEmpty) return const SizedBox.shrink();
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _navigateToAddressPage(context, ref),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.location_off,
                                          color: Colors.red.shade700,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Delivery address required',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: const Color(0xFF1A1A1A),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add a delivery address to complete your order. Required for checkout.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: const Color(0xFF757575),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.red.shade700,
                                          size: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Delivery Details Section
                  const DeliveryDetailsSection(),
                ],
              ),
            ),
          ),

          // Cart Summary and Checkout
          _buildCartSummary(context, theme, cartState, ref, pendingOrder),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: theme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious items to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.safeGoBack(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Browse Menu'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(
      BuildContext context, ThemeData theme, CartState cartState, WidgetRef ref,
      [OrderResponse? pendingOrder]) {
    final tempDiscountState = ref.watch(tempDiscountProvider);
    final selectedDiscount = tempDiscountState.selectedDiscount;
    
    // Calculate discount amount
    double discountAmount = 0.0;
    if (selectedDiscount != null) {
      final tempDiscountNotifier = ref.read(tempDiscountProvider.notifier);
      if (tempDiscountNotifier.isDiscountApplicable(cartState.totalPrice, null)) {
        discountAmount = tempDiscountNotifier.calculateDiscountAmount(cartState.totalPrice);
      }
    }
    
    final finalTotal = cartState.totalPrice - discountAmount;

    return Container(
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
            // Discount Section
            if (selectedDiscount != null) ...[
              _buildDiscountSection(context, theme, ref, selectedDiscount, cartState.totalPrice, discountAmount),
              const SizedBox(height: 16),
            ] else ...[
              _buildDiscountSelector(context, theme, ref, cartState.totalPrice),
              const SizedBox(height: 16),
            ],

            // Price breakdown
            _buildPriceBreakdown(context, theme, cartState, discountAmount, finalTotal),

            const SizedBox(height: 16),

            // Checkout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _handleCheckout(context, ref, pendingOrder);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  pendingOrder != null ? 'Update Order' : 'Proceed to Checkout',
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
    );
  }

  void _editCartItem(BuildContext context, CartItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductCustomizationPage(
          product: item.product,
          isBestSeller: item.isBestSeller,
          cartId: item.id,
          existingCartItem: item,
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartNotifier cartNotifier,
      OrderResponse? pendingOrder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
            'Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => context.safeGoBack(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final orderService = serviceLocator<OrderService>();
              try {
                if (pendingOrder?.id.isNotEmpty ?? false) {
                  await orderService.deletePendingOrder(pendingOrder!.id);
                }
              } catch (e) {
                debugPrint('Error clearing pending order: $e');
              }

              Navigator.of(context)
                  .pop(); // context.safeGoBack(); // Close dialog
              await cartNotifier.clearCart();
              final deliveryNotifier = ref.read(deliveryProvider.notifier);
              deliveryNotifier.updateOrderComment('');
              // Invalidate the pending order provider to refresh the UI
              ref.invalidate(recentPendingOrderWithRefreshProvider);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // Widget _buildPendingOrderPage(BuildContext context, ThemeData theme,
  //     OrderResponse pendingOrder, WidgetRef ref) {
  //   return Scaffold(
  //     appBar: CustomAppBar(title: 'Pending Order'),
  //     body: Column(
  //       children: [
  //         // Pending order info
  //         Container(
  //           width: double.infinity,
  //           padding: const EdgeInsets.all(20),
  //           margin: const EdgeInsets.all(16),
  //           decoration: BoxDecoration(
  //             color: theme.colorScheme.primary.withOpacity(0.1),
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(
  //               color: theme.colorScheme.primary.withOpacity(0.2),
  //             ),
  //           ),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 children: [
  //                   Icon(
  //                     Icons.info_outline,
  //                     color: theme.colorScheme.primary,
  //                     size: 20,
  //                   ),
  //                   const SizedBox(width: 8),
  //                   Text(
  //                     'You have a pending order',
  //                     style: theme.textTheme.titleMedium?.copyWith(
  //                       color: theme.colorScheme.primary,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 'Order #${pendingOrder.orderNo}',
  //                 style: theme.textTheme.bodyLarge?.copyWith(
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 '${pendingOrder.items.length} items • ₱${pendingOrder.totalAmountPay.toStringAsFixed(2)}',
  //                 style: theme.textTheme.bodyMedium?.copyWith(
  //                   color: theme.textSecondary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),

  //         // Order items list
  //         Expanded(
  //           child: ListView.separated(
  //             padding: const EdgeInsets.symmetric(horizontal: 16),
  //             itemCount: pendingOrder.items.length,
  //             separatorBuilder: (context, index) => const SizedBox(height: 12),
  //             itemBuilder: (context, index) {
  //               final item = pendingOrder.items[index];
  //               return _buildPendingOrderItem(context, theme, item);
  //             },
  //           ),
  //         ),

  //         // Action buttons
  //         Container(
  //           padding: const EdgeInsets.all(20),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             border: Border(
  //               top: BorderSide(color: theme.borderColor, width: 1),
  //             ),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withOpacity(0.05),
  //                 blurRadius: 10,
  //                 offset: const Offset(0, -2),
  //               ),
  //             ],
  //           ),
  //           child: SafeArea(
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 // Continue to payment button
  //                 SizedBox(
  //                   width: double.infinity,
  //                   height: 50,
  //                   child: ElevatedButton(
  //                     onPressed: () {
  //                       context.go('/order/checkout/${pendingOrder.id}');
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: theme.colorScheme.primary,
  //                       foregroundColor: Colors.white,
  //                       elevation: 0,
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                     ),
  //                     child: Text(
  //                       'Continue to Payment',
  //                       style: theme.textTheme.titleMedium?.copyWith(
  //                         color: Colors.white,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 // Load to cart button
  //                 SizedBox(
  //                   width: double.infinity,
  //                   height: 50,
  //                   child: OutlinedButton(
  //                     onPressed: () =>
  //                         _loadPendingOrderToCart(context, ref, pendingOrder),
  //                     style: OutlinedButton.styleFrom(
  //                       side: BorderSide(color: theme.colorScheme.secondary),
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                     ),
  //                     child: Text(
  //                       'Load to Cart',
  //                       style: theme.textTheme.titleMedium?.copyWith(
  //                         color: theme.colorScheme.secondary,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 // Add more items button
  //                 SizedBox(
  //                   width: double.infinity,
  //                   height: 50,
  //                   child: OutlinedButton(
  //                     onPressed: () {
  //                       Navigator.of(context).pop(); // Go back to menu
  //                     },
  //                     style: OutlinedButton.styleFrom(
  //                       side: BorderSide(color: theme.colorScheme.primary),
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                     ),
  //                     child: Text(
  //                       'Add More Items',
  //                       style: theme.textTheme.titleMedium?.copyWith(
  //                         color: theme.colorScheme.primary,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPendingOrderItem(
      BuildContext context, ThemeData theme, OrderItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor, width: 1),
      ),
      child: Row(
        children: [
          // Item image placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.size.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${item.size}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textSecondary,
                    ),
                  ),
                ],
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Add-ons: ${item.addons.map((a) => a.name).join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${item.qty}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₱${item.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPendingOrderModal(
      BuildContext context, OrderResponse pendingOrder, WidgetRef ref) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Pending Order Found'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have a pending order with ${pendingOrder.items.length} items.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${pendingOrder.orderNo}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.safeGoBack(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              context.safeGoBack();
              _mergePendingOrderToCart(context, ref, pendingOrder);
            },
            child: const Text('Merge to Cart'),
          ),
          ElevatedButton(
            onPressed: () {
              context.safeGoBack();
              context.go('/order/checkout/${pendingOrder.id}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text('View Order'),
          ),
        ],
      ),
    );
  }

  // Silently load pending order to cart without user interaction
  Future<void> _loadPendingOrderToCartSilently(
      WidgetRef ref, OrderResponse pendingOrder) async {
    final cartNotifier = ref.read(cartProvider.notifier);

    try {
      // Convert order items to cart items
      for (final orderItem in pendingOrder.items) {
        // Create a product map from order item data
        final product = {
          '_id': orderItem.itemId,
          'id': orderItem.itemId,
          'name': orderItem.itemName,
        };

        // Create a variant map - fix for item name duplication
        final variant = {
          '_id': orderItem.itemId,
          'id': orderItem.itemId,
          'name': '', // Don't use size as name to avoid duplication
          'size': orderItem.size,
          'price': orderItem.price,
        };

        // Convert addons to the expected format
        final addonsMap = <String, int>{};
        final addonMetadata = <Map<String, dynamic>>[];

        for (final addon in orderItem.addons) {
          addonsMap[addon.addonId] = addon.qty;
          addonMetadata.add({
            '_id': addon.addonId,
            'id': addon.addonId,
            'name': addon.name,
            'price': addon.price,
          });
        }

        // Add to cart
        await cartNotifier.addItem(
          product: product,
          variant: variant,
          quantity: orderItem.qty,
          addons: addonsMap,
          addonMetadata: addonMetadata,
        );
      }
    } catch (e) {
      debugPrint('Error loading pending order to cart: $e');
    }
  }

  // Update pending order when cart changes
  Future<void> _updatePendingOrderFromCart(
      WidgetRef ref, OrderResponse pendingOrder) async {
    final cartState = ref.read(cartProvider);

    // Only update if there are items in cart
    if (cartState.items.isEmpty) return;

    try {
      final deliveryDetails = ref.read(deliveryProvider);
      final defaultAddressAsync = ref.read(defaultAddressProvider);

      await defaultAddressAsync.when(
        loading: () async {},
        error: (error, stack) async {},
        data: (defaultAddress) async {
          if (defaultAddress == null) return;

          // Get the current store ID from the pending order
          final storeId = pendingOrder.storeId;

          // Create order object from current cart
          final order = _createOrder(
              context, ref, deliveryDetails, defaultAddress, storeId);

          // Update the pending order
          final orderService = serviceLocator<OrderService>();
          await orderService.updateCustomerOrder(pendingOrder.id, order);

          debugPrint('Pending order updated automatically');
        },
      );
    } catch (e) {
      debugPrint('Error updating pending order: $e');
    }
  }

  Future<void> _mergePendingOrderToCart(
      BuildContext context, WidgetRef ref, OrderResponse pendingOrder) async {
    final cartNotifier = ref.read(cartProvider.notifier);

    try {
      // Show loading dialog with progress indication
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Merging ${pendingOrder.items.length} items to cart...'),
              const SizedBox(height: 8),
              const Text(
                'This may take a few moments',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Prepare all cart items first, then add them in batch
      final List<Future<void>> addOperations = [];

      // Convert order items to cart items and prepare batch operations
      for (final orderItem in pendingOrder.items) {
        // Create a product map from order item data
        final product = {
          '_id': orderItem.itemId,
          'id': orderItem.itemId,
          'name': orderItem.itemName,
        };

        // Create a variant map - fix for item name duplication (merge method)
        final variant = {
          '_id': orderItem.itemId, // Use original ID, don't append size
          'id': orderItem.itemId,
          'name': '', // Don't use size as name to avoid duplication
          'size': orderItem.size,
          'price': orderItem.price,
        };

        // Convert addons to the expected format
        final addonsMap = <String, int>{};
        final addonMetadata = <Map<String, dynamic>>[];

        for (final addon in orderItem.addons) {
          addonsMap[addon.addonId] = addon.qty;
          addonMetadata.add({
            '_id': addon.addonId,
            'id': addon.addonId,
            'name': addon.name,
            'price': addon.price,
          });
        }

        // Add the operation to the batch
        addOperations.add(cartNotifier.addItem(
          product: product,
          variant: variant,
          quantity: orderItem.qty,
          addons: addonsMap,
          addonMetadata: addonMetadata,
        ));
      }

      // Execute operations in batches to prevent overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < addOperations.length; i += batchSize) {
        final batch = addOperations.skip(i).take(batchSize).toList();
        await Future.wait(batch).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Merge operation timed out. Please try again.');
          },
        );
      }

      // Hide loading dialog
      if (context.mounted) {
        context.safeGoBack();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pendingOrder.items.length} items merged to cart'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      // Optionally, you might want to cancel the pending order here
      // or mark it as merged. For now, we'll leave it as is.
    } catch (e) {
      // Hide loading dialog if it's still showing
      if (context.mounted) {
        context.safeGoBack();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to merge order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPendingOrderToCart(
      BuildContext context, WidgetRef ref, OrderResponse pendingOrder) async {
    final cartNotifier = ref.read(cartProvider.notifier);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Order to Cart'),
        content: const Text(
            'This will replace your current cart items with the pending order items. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading dialog with progress indication
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading ${pendingOrder.items.length} items to cart...'),
              const SizedBox(height: 8),
              const Text(
                'This may take a few moments',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Clear current cart
      await cartNotifier.clearCart();

      // Prepare all cart items first, then add them in batch
      final List<Future<void>> addOperations = [];

      // Convert order items to cart items and prepare batch operations
      for (final orderItem in pendingOrder.items) {
        // Create a product map from order item data
        final product = {
          '_id': orderItem.itemId,
          'id': orderItem.itemId,
          'name': orderItem.itemName,
        };

        // Create a variant map - fix for item name duplication (load method)
        final variant = {
          '_id': orderItem.itemId, // Use original ID, don't append size
          'id': orderItem.itemId,
          'name': '', // Don't use size as name to avoid duplication
          'size': orderItem.size,
          'price': orderItem.price,
        };

        // Convert addons to the expected format
        final addonsMap = <String, int>{};
        final addonMetadata = <Map<String, dynamic>>[];

        for (final addon in orderItem.addons) {
          addonsMap[addon.addonId] = addon.qty;
          addonMetadata.add({
            '_id': addon.addonId,
            'id': addon.addonId,
            'name': addon.name,
            'price': addon.price,
          });
        }

        // Add the operation to the batch
        addOperations.add(cartNotifier.addItem(
          product: product,
          variant: variant,
          quantity: orderItem.qty,
          addons: addonsMap,
          addonMetadata: addonMetadata,
        ));
      }

      // Execute operations in batches to prevent overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < addOperations.length; i += batchSize) {
        final batch = addOperations.skip(i).take(batchSize).toList();
        await Future.wait(batch).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Load operation timed out. Please try again.');
          },
        );
      }

      // Hide loading dialog
      if (context.mounted) {
        context.safeGoBack();
      }

      // Show success message and navigate back
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pendingOrder.items.length} items loaded to cart'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Go back to cart view
        context.safeGoBack();
      }
    } catch (e) {
      // Hide loading dialog if it's still showing
      if (context.mounted) {
        context.safeGoBack();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCheckout(BuildContext context, WidgetRef ref,
      [OrderResponse? pendingOrder]) async {
    final deliveryDetails = ref.read(deliveryProvider);
    final defaultAddressAsync = ref.read(defaultAddressProvider);

    // Validate delivery details
    if (deliveryDetails.customerName == null ||
        deliveryDetails.customerName!.trim().isEmpty ||
        deliveryDetails.customerName!.trim() == 'Guest Customer') {
      _showValidationError(context,
          'Please provide a valid customer name. The name field is required for delivery.');
      return;
    }

    if (deliveryDetails.contactNumber.isEmpty) {
      _showValidationError(context, 'Please provide a contact number');
      return;
    }

    if (!deliveryDetails.hasAddress) {
      _showAddressRequiredDialog(context, ref);
      return;
    }

    // Get the current store ID
    final nearestStoreAsync = ref.read(nearestStoreWithRefreshProvider);
    String? storeId;

    await nearestStoreAsync.when(
      loading: () async {
        _showValidationError(context, 'Loading store information...');
        return;
      },
      error: (error, stack) async {
        _showValidationError(context, 'Failed to get store information');
        return;
      },
      data: (storeData) async {
        storeId = storeData.store?.id;

        if (storeId == null) {
          _showValidationError(context, 'No store selected');
          return;
        }

        // Get default address for order creation
        defaultAddressAsync.when(
          loading: () => _showLoadingDialog(context),
          error: (error, stack) => _showValidationError(
              context, 'Failed to load address information'),
          data: (defaultAddress) async {
            if (defaultAddress == null) {
              _showAddressRequiredDialog(context, ref);
              return;
            }

            // Create order object with dynamic store ID
            final order = _createOrder(
                context, ref, deliveryDetails, defaultAddress, storeId!);

            try {
              // Show loading
              _showLoadingDialog(context);

              final orderService = serviceLocator<OrderService>();
              OrderResponse orderResponse;

              if (pendingOrder != null) {
                // Update existing order
                orderResponse = await orderService.updateCustomerOrder(
                    pendingOrder.id, order);
                print(
                    'Order updated successfully with ID: ${orderResponse.id}');
              } else {
                // Create new order
                orderResponse = await orderService.createCustomerOrder(order);
                print(
                    'Order created successfully with ID: ${orderResponse.id}');
              }

              // Hide loading dialog
              if (context.mounted) {
                context.safeGoBack();
              }

              // Clear cart after successful checkout
              final cartNotifier = ref.read(cartProvider.notifier);
              await cartNotifier.clearCart();

// Clear delivery details including order comment for new orders
              final deliveryNotifier = ref.read(deliveryProvider.notifier);
              deliveryNotifier.updateOrderComment('');
              // Add this method to your delivery provider

              // Navigate to order summary page with orderId
              if (context.mounted) {
                final navigationUrl = '/order/checkout/${orderResponse.id}';
                print('Navigating to: $navigationUrl');
                context.push(navigationUrl);
              }
            } catch (e) {
              // Hide loading dialog
              if (context.mounted) {
                context.safeGoBack();
              }

              print('Error during checkout: $e');
              if (e == 'Store is currently closed') {
                _showValidationError(context, 'Store is currently closed');
                return;
              }
              _showValidationError(context,
                  'Failed to ${pendingOrder != null ? 'update' : 'create'} order: $e');
            }
          },
        );
      },
    );
  }

  // Build discount selector when no discount is applied
  Widget _buildDiscountSelector(BuildContext context, ThemeData theme, WidgetRef ref, double orderTotal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () => _showDiscountSelectionModal(context, ref, orderTotal),
        icon: const Icon(Icons.local_offer_outlined),
        label: const Text('Apply Discount'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // Build discount section when discount is applied
  Widget _buildDiscountSection(BuildContext context, ThemeData theme, WidgetRef ref, 
      DiscountModel discount, double orderTotal, double discountAmount) {
    final tempDiscountNotifier = ref.read(tempDiscountProvider.notifier);
    final validationMessage = tempDiscountNotifier.getDiscountValidationMessage(orderTotal);
    final isValid = validationMessage == null;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.local_offer : Icons.error_outline,
                color: isValid ? Colors.green[600] : Colors.red[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  discount.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isValid ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isValid)
                Text(
                  '-₱${discountAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              IconButton(
                onPressed: () => ref.read(tempDiscountProvider.notifier).clearDiscount(),
                icon: const Icon(Icons.close),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (!isValid) ...[
            const SizedBox(height: 4),
            Text(
              validationMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build price breakdown
  Widget _buildPriceBreakdown(BuildContext context, ThemeData theme, CartState cartState, 
      double discountAmount, double finalTotal) {
    return Column(
      children: [
        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtotal (${cartState.totalItems} items)',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '₱${cartState.totalPrice.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        
        // Discount (if applied)
        if (discountAmount > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green[600],
                ),
              ),
              Text(
                '-₱${discountAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        ],
        
        const Divider(height: 16),
        
        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '₱${finalTotal.toStringAsFixed(2)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Show discount selection modal
  void _showDiscountSelectionModal(BuildContext context, WidgetRef ref, double orderTotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DiscountSelectionModal(orderTotal: orderTotal),
    );
  }
}

Order _createOrder(BuildContext context, WidgetRef ref,
    DeliveryDetails deliveryDetails, Address address, String storeId) {
  final cartState = ref.read(cartProvider);

  // Get selected discount from temp discount provider
  final tempDiscountState = ref.read(tempDiscountProvider);
  final selectedDiscount = tempDiscountState.selectedDiscount;
  
  OrderDiscount? orderDiscount;
  if (selectedDiscount != null) {
    final tempDiscountNotifier = ref.read(tempDiscountProvider.notifier);
    if (tempDiscountNotifier.isDiscountApplicable(cartState.totalPrice, null)) {
      orderDiscount = OrderDiscount(
        type: selectedDiscount.type.name, // 'percentage' or 'fixed'
        value: selectedDiscount.value,
        id: selectedDiscount.id,
        name: selectedDiscount.name,
      );
    }
  }

  // Determine customer name with priority: deliveryDetails.customerName -> userProfile -> 'Guest Customer'
  String customerName = '';

  if (deliveryDetails.customerName != null &&
      deliveryDetails.customerName!.trim().isNotEmpty) {
    customerName = deliveryDetails.customerName!.trim();
  }

  //  respect user input dont auto-fill on checkout
  // else {
  //   // Try to get from user profile as fallback
  //   final userProfileAsync = ref.read(userProfileProvider);
  //   userProfileAsync.when(
  //     data: (userProfile) {
  //       if (userProfile.name.isNotEmpty) {
  //         customerName = userProfile.name;
  //       }
  //     },
  //     loading: () {},
  //     error: (_, __) {},
  //   );
  // }

  return Order(
    storeId: storeId,
    items: cartState.items
        .map((cartItem) => OrderItem.fromCartItem(cartItem))
        .toList(),
    customerName: customerName,
    orderComment: deliveryDetails.orderComment ?? '',
    deliveryInfo: OrderDeliveryInfo.fromDeliveryDetailsAndAddress(
        deliveryDetails, address),
    paymentMethod: [], // Default payment method
    discount: orderDiscount,
  );
}

void _showValidationError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}

void _showAddressRequiredDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Delivery Address Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To complete your order, please add a delivery address.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your address will be saved for future orders and set as default.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.safeGoBack(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            context.safeGoBack();
            _navigateToAddressPage(context, ref);
          },
          icon: const Icon(Icons.add_location),
          label: const Text('Add Address Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

void _navigateToAddressPage(BuildContext context, WidgetRef ref) {
  Navigator.of(context)
      .push(
    MaterialPageRoute(
      builder: (context) => const AddressManagementPage(),
    ),
  )
      .then((_) {
    // Refresh address data when returning
    ref.invalidate(defaultAddressProvider);
  });
}

void _showLoadingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Loading...'),
        ],
      ),
    ),
  );
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _CartItemCard({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.restaurant_outlined,
                              color: theme.textSecondary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.restaurant_outlined,
                        color: theme.textSecondary,
                      ),
              ),

              const SizedBox(width: 12),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      item.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Best Seller Badge
                    if (item.isBestSeller) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                      const SizedBox(height: 4),
                    ],

                    // Addons (if any)
                    if (item.addons.isNotEmpty) ...[
                      Text(
                        _buildAddonText(item.addons),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Price
                    Text(
                      '₱${item.totalPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit Button
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit item',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 8),

              // Remove Button
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Remove item',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quantity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textSecondary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: item.quantity > 1
                          ? () {
                              onQuantityChanged(item.quantity - 1);
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                      iconSize: 16,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        item.quantity.toString(),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        onQuantityChanged(item.quantity + 1);
                      },
                      icon: const Icon(Icons.add),
                      iconSize: 16,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildAddonText(List<Addon> addons) {
    if (addons.isEmpty) return '';

    final addonTexts =
        addons.map((addon) => '${addon.qty}x ${addon.name}').toList();

    return 'Add-ons: ${addonTexts.join(', ')}';
  }
}

// Discount selection modal widget
class _DiscountSelectionModal extends ConsumerWidget {
  final double orderTotal;

  const _DiscountSelectionModal({required this.orderTotal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final discountsAsync = ref.watch(discountsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Discount',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Discounts list
          discountsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load discounts',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red[600],
                  ),
                ),
              ),
            ),
            data: (discounts) {
              final activeDiscounts = discounts.where((d) => d.isActive).toList();
              
              if (activeDiscounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No discounts available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                );
              }
              
              return ListView.separated(
                shrinkWrap: true,
                itemCount: activeDiscounts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final discount = activeDiscounts[index];
                  
                  // Check discount applicability directly
                  bool isApplicable = discount.isActive;
                  double discountAmount = 0.0;
                  String? validationMessage;
                  
                  // Check date validity
                  final now = DateTime.now();
                  if (discount.startDate != null && now.isBefore(discount.startDate!)) {
                    isApplicable = false;
                    validationMessage = 'This discount is not yet available';
                  } else if (discount.endDate != null && now.isAfter(discount.endDate!)) {
                    isApplicable = false;
                    validationMessage = 'This discount has expired';
                  }
                  
                  // Check minimum purchase amount
                  if (isApplicable && discount.minPurchaseAmount != null && 
                      orderTotal < discount.minPurchaseAmount!) {
                    isApplicable = false;
                    validationMessage = 'Minimum purchase of ₱${discount.minPurchaseAmount!.toStringAsFixed(2)} required';
                  }
                  
                  // Calculate discount amount if applicable
                  if (isApplicable) {
                    switch (discount.type) {
                      case DiscountType.percentage:
                        discountAmount = orderTotal * (discount.value / 100);
                        break;
                      case DiscountType.fixed:
                        discountAmount = discount.value;
                        break;
                    }
                  }
                  
                  return _DiscountItem(
                    discount: discount,
                    orderTotal: orderTotal,
                    isApplicable: isApplicable,
                    discountAmount: discountAmount,
                    validationMessage: validationMessage,
                    onTap: () {
                      if (isApplicable) {
                        ref.read(tempDiscountProvider.notifier).selectDiscount(discount);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Discount "${discount.name}" applied!'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Individual discount item widget
class _DiscountItem extends StatelessWidget {
  final DiscountModel discount;
  final double orderTotal;
  final bool isApplicable;
  final double discountAmount;
  final String? validationMessage;
  final VoidCallback onTap;

  const _DiscountItem({
    required this.discount,
    required this.orderTotal,
    required this.isApplicable,
    required this.discountAmount,
    this.validationMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: isApplicable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isApplicable ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isApplicable ? theme.colorScheme.primary.withOpacity(0.3) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    discount.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isApplicable ? null : Colors.grey[600],
                    ),
                  ),
                ),
                if (isApplicable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-₱${discountAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (discount.description != null)
              Text(
                discount.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isApplicable ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            if (!isApplicable && validationMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                validationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
