import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/components/custom_app_bar.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/models/store_model.dart';
import 'product_customization_page.dart';

class MenuPage extends ConsumerStatefulWidget {
  final String? categoryFilter;
  final String? itemId;

  const MenuPage({
    super.key,
    this.categoryFilter,
    this.itemId,
  });

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  List<String> categories = ['All']; // Start with 'All' as default
  Map<String, GlobalKey> categoryKeys = {};
  final GlobalKey _bestSellerKey = GlobalKey();
  bool _isScrollingToCategory = false;
  bool _hasHandledItemId = false; // Flag to prevent multiple modal openings
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isBottomSheetVisible = true;
  double _lastScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    );
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    
    // Start with bottom sheet visible
    _bottomSheetController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _bottomSheetController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
  }

  // Method to update categories when products are loaded
  void _updateCategories(List<Map<String, dynamic>> products) {
    final Set<String> categorySet = {};

    for (final product in products) {
      final categoryMain = product['category']?['main']?.toString();
      if (categoryMain != null && categoryMain.isNotEmpty) {
        categorySet.add(categoryMain);
      }
    }

    // Sort categories alphabetically and add 'All' at the beginning
    final sortedCategories = categorySet.toList()..sort();
    final newCategories = ['All', ...sortedCategories];

    // Check if categories have changed
    bool categoriesChanged = newCategories.length != categories.length;
    if (!categoriesChanged) {
      for (int i = 0; i < newCategories.length; i++) {
        if (newCategories[i] != categories[i]) {
          categoriesChanged = true;
          break;
        }
      }
    }

    if (categoriesChanged) {
      setState(() {
        categories = newCategories;
        // Create keys for each category section (excluding 'All')
        categoryKeys = {};
        for (final category in categories) {
          if (category != 'All') {
            categoryKeys[category] = GlobalKey();
          }
        }
        _tabController.dispose();
        _tabController = TabController(length: categories.length, vsync: this);
      });

      // Debug information
      print('Categories updated: $categories');
      print('Category keys created: ${categoryKeys.keys.toList()}');

      // Handle category navigation after categories are updated
      if (widget.categoryFilter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToCategory(widget.categoryFilter!);
        });
      }
    }
  }

  // Handle scroll events to update active tab and bottom sheet visibility
  void _onScroll() {
    if (_isScrollingToCategory) return;

    final scrollOffset = _scrollController.offset;
    final scrollDelta = scrollOffset - _lastScrollOffset;
    
    // Handle bottom sheet visibility based on scroll direction
    if (scrollDelta > 5 && _isBottomSheetVisible) {
      // Scrolling down - hide bottom sheet
      setState(() {
        _isBottomSheetVisible = false;
      });
      _bottomSheetController.reverse();
    } else if (scrollDelta < -5 && !_isBottomSheetVisible) {
      // Scrolling up - show bottom sheet
      setState(() {
        _isBottomSheetVisible = true;
      });
      _bottomSheetController.forward();
    }
    
    _lastScrollOffset = scrollOffset;

    // Tab switching logic (existing code)
    // If we're at the very top, show "All"
    if (scrollOffset < 50) {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
      return;
    }

    // Find the category whose section is currently at the top of the viewport
    String targetCategory = 'All';
    double closestDistance = double.infinity;

    // Check Best Seller section
    final bestSellerContext = _bestSellerKey.currentContext;
    if (bestSellerContext != null) {
      final box = bestSellerContext.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final sectionTop = position.dy;

      // If Best Seller section is in the viewport area where tabs should switch
      if (sectionTop <= 250 && sectionTop >= -100) {
        final distance = (sectionTop - 150).abs(); // 150 is our target position
        if (distance < closestDistance) {
          closestDistance = distance;
          targetCategory = 'All';
        }
      }
    }

    // Check each category section in order
    for (final category in categories) {
      if (category == 'All') continue;

      final key = categoryKeys[category];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final sectionTop = position.dy;

        // Category becomes active when its header reaches the switch zone
        if (sectionTop <= 250 && sectionTop >= -100) {
          final distance =
              (sectionTop - 150).abs(); // 150 is our target position
          if (distance < closestDistance) {
            closestDistance = distance;
            targetCategory = category;
          }
        }
      }
    }

    // Only update if we have a clear winner and it's different from current
    final targetIndex = categories.indexOf(targetCategory);
    if (targetIndex != -1 &&
        targetIndex != _tabController.index &&
        closestDistance < 200) {
      _tabController.animateTo(targetIndex);
    }
  }

  // Scroll to specific category section
  void _scrollToCategory(String category) {
    if (category == 'All') {
      _isScrollingToCategory = true;
      _scrollController
          .animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _isScrollingToCategory = false;
      });
      return;
    }

    final key = categoryKeys[category];
    if (key?.currentContext != null) {
      _isScrollingToCategory = true;
      
      try {
        // Get the RenderBox of the category section
        final RenderBox? box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final Offset position = box.localToGlobal(Offset.zero);
          
          // Calculate the scroll offset needed
          // We need to account for the app bar, store info, search bar, and category tabs
          // Using more conservative estimates
          final double headerOffset = 200.0; // Total estimated header height
          
          // Calculate target scroll position
          final double targetScrollOffset = _scrollController.offset + position.dy - headerOffset;
          
          // Ensure we don't scroll beyond the content
          final double maxScrollExtent = _scrollController.position.maxScrollExtent;
          final double clampedOffset = targetScrollOffset.clamp(0.0, maxScrollExtent);
          
          _scrollController
              .animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          )
              .then((_) {
            _isScrollingToCategory = false;
          });
          
          print('Scrolling to category: $category, target offset: $clampedOffset');
        } else {
          print('RenderBox not found for category: $category');
          _isScrollingToCategory = false;
        }
      } catch (e) {
        print('Error scrolling to category $category: $e');
        _isScrollingToCategory = false;
      }
    } else {
      print('Category key context not found for: $category');
      
      // Fallback: try using Scrollable.ensureVisible
      if (key?.currentContext != null) {
        _isScrollingToCategory = true;
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ).then((_) {
          _isScrollingToCategory = false;
        });
      } else {
        _isScrollingToCategory = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Menu',
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Store information section
              _buildStoreInfoSection(theme),

              // Search Bar
              _buildSearchBar(theme),

              // Category Tabs - Hide when searching
              if (!_isSearching) _buildCategoryTabs(theme),

              // Menu Content
              Expanded(
                child: _buildMenuContent(),
              ),
            ],
          ),
          
          // Animated Bottom Sheet
          _buildAnimatedBottomSheet(theme),
        ],
      ),
    );
  }

  Widget _buildStoreInfoSection(ThemeData theme) {
    final nearestStoreAsync = ref.watch(nearestStoreWithRefreshProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: nearestStoreAsync.when(
        loading: () => Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: const Color(0xFF757575),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Finding your nearest store...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF757575),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        error: (error, stack) => Row(
          children: [
            Icon(
              Icons.location_off,
              size: 14,
              color: Colors.orange[600],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'We couldn\'t find any stores nearby',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange[600],
                ),
              ),
            ),
            // Refresh button
            IconButton(
              onPressed: () {
                ref.read(refreshNearestStoreProvider.notifier).state++;
              },
              icon: Icon(
                Icons.refresh,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Refresh nearest store',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
        data: (storeData) {
          if (storeData.store != null) {
            final store = storeData.store!;
            final isStoreOpen = store.isCurrentlyOpen;
            final isClosed = store.isClosed ?? false;
            
            return Row(
              children: [
                Icon(
                  Icons.place,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF757575),
                          ),
                          children: (isClosed || !isStoreOpen) ? [
                            TextSpan(
                              text: store.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const TextSpan(text: ' is closed and cannot cater your order right now'),
                          ] : [
                            const TextSpan(text: 'Delivering from '),
                            TextSpan(
                              text: store.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (storeData.usedCurrentLocation && (isStoreOpen && !isClosed))
                            Expanded(
                              child: Text(
                                '• Based on your current location',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF999999),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: () {
                    ref.read(refreshNearestStoreProvider.notifier).state++;
                  },
                  icon: Icon(
                    Icons.refresh,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Refresh nearest store',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Icon(
                  Icons.location_searching,
                  size: 14,
                  color: const Color(0xFF999999),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No delivery available in your area yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF999999),
                    ),
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: () {
                    ref.read(refreshNearestStoreProvider.notifier).state++;
                  },
                  icon: Icon(
                    Icons.refresh,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Refresh nearest store',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: _isSearching ? Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: _isSearching ? theme.colorScheme.primary : theme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textSecondary,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (_isSearching)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                },
                icon: Icon(
                  Icons.clear,
                  size: 20,
                  color: theme.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(ThemeData theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.textSecondary,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 2,
        labelStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.titleMedium,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        onTap: (index) {
          final category = categories[index];
          print('Tab clicked: $category at index $index');
          
          // Add a small delay to ensure the tab animation completes
          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToCategory(category);
          });
        },
        tabs: categories.map((category) => Tab(text: category)).toList(),
      ),
    );
  }

  Widget _buildAnimatedBottomSheet(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: const Offset(0, 0),
        ).animate(_bottomSheetAnimation),
        child: Consumer(
          builder: (context, ref, child) {
            final nearestStoreAsync = ref.watch(nearestStoreWithRefreshProvider);
            final cartItemCount = ref.watch(cartItemCountProvider);

            return nearestStoreAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (storeData) {
                final store = storeData.store;
                final isStoreOpen = store?.isCurrentlyOpen ?? true;
                final isClosed = store?.isClosed ?? false;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle bar
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Store info and cart section
                          Row(
                            children: [
                              // Store info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (store != null) ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: (isClosed || !isStoreOpen) 
                                                  ? Colors.red[50]
                                                  : Colors.green[50],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              (isClosed || !isStoreOpen) 
                                                  ? Icons.store_mall_directory_outlined
                                                  : Icons.store,
                                              size: 16,
                                              color: (isClosed || !isStoreOpen) 
                                                  ? Colors.red[600]
                                                  : Colors.green[600],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              store.name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.location_searching,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'No stores available',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Cart button - only show when store is open
                              if (store != null && !isClosed && isStoreOpen) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        // Navigate to cart using go_router
                                        context.go('/cart');
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Icon(
                                                  Icons.shopping_cart_outlined,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                if (cartItemCount > 0)
                                                  Positioned(
                                                    right: -8,
                                                    top: -8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 16,
                                                        minHeight: 16,
                                                      ),
                                                      child: Text(
                                                        cartItemCount > 99 ? '99+' : cartItemCount.toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              cartItemCount > 0 
                                                  ? 'Cart ($cartItemCount)'
                                                  : 'Cart',
                                              style: theme.textTheme.labelLarge?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Show store hours when closed
                          if (store != null && (isClosed || !isStoreOpen)) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Store Hours',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    store.getFormattedHours(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuContent() {
    final theme = Theme.of(context);
    final nearestStoreAsync = ref.watch(nearestStoreWithRefreshProvider);

    return nearestStoreAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading menu: $error'),
            ElevatedButton(
              onPressed: () {
                ref.read(refreshNearestStoreProvider.notifier).state++;
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (storeData) {
        // Get store ID if available
        final storeId = storeData.store?.id;

        // Watch products provider with store ID
        final productsAsync = ref.watch(menuProductsProvider(storeId));

        return productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading products: $error'),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(menuProductsProvider(storeId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (products) {
            // Update categories when products are loaded
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateCategories(products);

              // Handle itemId parameter if provided (only once)
              if (widget.itemId != null && !_hasHandledItemId) {
                _hasHandledItemId = true;
                _handleItemIdNavigation(products, widget.itemId!);
              }
            });

            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 64,
                      color: theme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back soon for menu updates',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group products by category
            final Map<String, List<Map<String, dynamic>>> productsByCategory =
                {};
            for (final product in products) {
              final categoryMain =
                  product['category']?['main']?.toString() ?? 'Uncategorized';
              if (!productsByCategory.containsKey(categoryMain)) {
                productsByCategory[categoryMain] = [];
              }
              productsByCategory[categoryMain]!.add(product);
            }

            // If searching, show search results instead
            if (_isSearching) {
              return _buildSearchResults(products);
            }

            return SingleChildScrollView(
              controller: _scrollController,
              child: nearestStoreAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading store: $error'),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(refreshNearestStoreProvider.notifier).state++;
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (storeData) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Best Seller Section (first 4 products from all categories)
                    if (products.isNotEmpty) ...[
                      Padding(
                        key: _bestSellerKey,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Best Seller',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount:
                                  products.length > 4 ? 4 : products.length,
                              itemBuilder: (context, index) =>
                                  _buildBestSellerItem(products[index], index, storeData),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Category Sections - Display in same order as tabs
                    ...categories
                        .where((category) => category != 'All')
                        .map((categoryName) {
                      final categoryProducts =
                          productsByCategory[categoryName] ?? [];

                      if (categoryProducts.isEmpty)
                        return const SizedBox.shrink();

                      return Column(
                        key: categoryKeys[categoryName],
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              categoryName,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Category Products
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: categoryProducts.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.borderColor,
                                indent:
                                    84, // Align with text content (68px image + 16px gap)
                                endIndent: 0,
                              ),
                              itemBuilder: (context, index) =>
                                  _buildProductListItem(
                                      categoryProducts[index], index, storeData),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),

                    const SizedBox(
                        height: 100), // Space for floating action button
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(List<Map<String, dynamic>> allProducts) {
    final theme = Theme.of(context);
    final nearestStoreAsync = ref.watch(nearestStoreWithRefreshProvider);
    
    // Filter products based on search query
    final filteredProducts = allProducts.where((product) {
      final productName = (product['name'] ?? '').toString().toLowerCase();
      final categoryName = (product['category']?['main'] ?? '').toString().toLowerCase();
      final variants = product['variants'] as List<dynamic>? ?? [];
      
      // Search in product name
      if (productName.contains(_searchQuery)) {
        return true;
      }
      
      // Search in category name
      if (categoryName.contains(_searchQuery)) {
        return true;
      }
      
      // Search in variant names
      for (final variant in variants) {
        final variantName = (variant['name'] ?? '').toString().toLowerCase();
        final variantSize = (variant['size'] ?? '').toString().toLowerCase();
        if (variantName.contains(_searchQuery) || variantSize.contains(_searchQuery)) {
          return true;
        }
      }
      
      return false;
    }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search results header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text(
              '${filteredProducts.length} result${filteredProducts.length == 1 ? '' : 's'} found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Search results list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredProducts.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: theme.borderColor,
                indent: 84,
                endIndent: 0,
              ),
              itemBuilder: (context, index) => _buildSearchResultItem(
                filteredProducts[index], 
                index,
                nearestStoreAsync,
              ),
            ),
          ),
          
          const SizedBox(height: 120), // Space for bottom sheet
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> product, int index, AsyncValue<({Store? store, bool usedCurrentLocation})> nearestStoreAsync) {
    final theme = Theme.of(context);

    // Handle both grouped and individual product structures
    final String productName = product['name'] ?? 'Unknown Product';
    final List<dynamic> variants = product['variants'] ?? [];
    final Map<String, dynamic>? category = product['category'];

    // Get the lowest price from variants
    double lowestPrice = 0.0;
    String image = '';

    if (variants.isNotEmpty) {
      // Find the lowest price among variants
      lowestPrice = variants
          .map((variant) => (variant['price'] ?? 0.0).toDouble())
          .reduce((a, b) => a < b ? a : b);

      // Find an image from variants (prefer first non-empty image)
      for (final variant in variants) {
        final variantImage = variant['image']?.toString() ?? '';
        if (variantImage.isNotEmpty) {
          image = variantImage;
          break;
        }
      }
    } else {
      lowestPrice = (product['price'] ?? 0.0).toDouble();
      image = product['image']?.toString() ?? '';
    }

    final String categoryName = category?['main'] ?? 'Uncategorized';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: () => _openItemCustomization(product),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.restaurant_outlined,
                                size: 24,
                                color: theme.textSecondary,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.restaurant_outlined,
                          size: 24,
                          color: theme.textSecondary,
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.titleMedium,
                        children: _buildHighlightedTextSpans(productName, theme),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      variants.isNotEmpty
                          ? '${variants.length} variant${variants.length > 1 ? 's' : ''} available'
                          : categoryName,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₱${lowestPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (variants.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '+ more',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Add to Cart Button
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openItemCustomization(product),
                    child: Center(
                      child: Text(
                        'Add',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TextSpan> _buildHighlightedTextSpans(String text, ThemeData theme) {
    if (_searchQuery.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final RegExp regex = RegExp(_searchQuery, caseSensitive: false);
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  Widget _buildBestSellerItem(Map<String, dynamic> product, int index, ({Store? store, bool usedCurrentLocation}) storeData) {
    final theme = Theme.of(context);

    // Handle both grouped and individual product structures
    final String productName = product['name'] ?? 'Unknown Product';
    final List<dynamic> variants = product['variants'] ?? [];

    // Get the lowest price from variants
    double lowestPrice = 0.0;
    String image = '';

    if (variants.isNotEmpty) {
      // Find the lowest price among variants
      lowestPrice = variants
          .map((variant) => (variant['price'] ?? 0.0).toDouble())
          .reduce((a, b) => a < b ? a : b);

      // Find an image from variants (prefer first non-empty image)
      for (final variant in variants) {
        final variantImage = variant['image']?.toString() ?? '';
        if (variantImage.isNotEmpty) {
          image = variantImage;
          break;
        }
      }
    } else {
      lowestPrice = (product['price'] ?? 0.0).toDouble();
      image = product['image']?.toString() ?? '';
    }

    return GestureDetector(
      onTap: () => _openItemCustomization(product, isBestSeller: true),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  color: theme.colorScheme.surfaceVariant,
                ),
                child: image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.restaurant_outlined,
                                size: 24,
                                color: theme.textSecondary,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.restaurant_outlined,
                          size: 24,
                          color: theme.textSecondary,
                        ),
                      ),
              ),
            ),

            // Item Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      productName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₱${lowestPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product, int index, ({Store? store, bool usedCurrentLocation}) storeData) {
    final theme = Theme.of(context);

    // Handle both grouped and individual product structures
    final String productName = product['name'] ?? 'Unknown Product';
    final List<dynamic> variants = product['variants'] ?? [];
    final Map<String, dynamic>? category = product['category'];

    // Get the lowest price from variants
    double lowestPrice = 0.0;
    String image = '';

    if (variants.isNotEmpty) {
      // Find the lowest price among variants
      lowestPrice = variants
          .map((variant) => (variant['price'] ?? 0.0).toDouble())
          .reduce((a, b) => a < b ? a : b);

      // Find an image from variants (prefer first non-empty image)
      for (final variant in variants) {
        final variantImage = variant['image']?.toString() ?? '';
        if (variantImage.isNotEmpty) {
          image = variantImage;
          break;
        }
      }
    } else {
      lowestPrice = (product['price'] ?? 0.0).toDouble();
      image = product['image']?.toString() ?? '';
    }

    final String categoryName = category?['main'] ?? 'Uncategorized';

    return GestureDetector(
      onTap: () => _openItemCustomization(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: image.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 24,
                              color: theme.textSecondary,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.restaurant_outlined,
                        size: 24,
                        color: theme.textSecondary,
                      ),
                    ),
            ),

            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    variants.isNotEmpty
                        ? '${variants.length} variant${variants.length > 1 ? 's' : ''} available'
                        : categoryName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₱${lowestPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (variants.length > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '+ more',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Add to Cart Button - Hide when store is closed
            () {
              final store = storeData.store;
              final isStoreOpen = store?.isCurrentlyOpen ?? true;
              final isClosed = store?.isClosed ?? false;
              
              if (isClosed || !isStoreOpen) {
                return const SizedBox.shrink(); // Hide button completely when closed
              }
              
              return Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openItemCustomization(product),
                    child: Center(
                      child: Text(
                        'Add',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
          ],
        ),
      ),
    );
  }

  void _openItemCustomization(Map<String, dynamic> product,
      {bool isBestSeller = false}) {
    // Navigate to product customization page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductCustomizationPage(
          product: product,
          isBestSeller: isBestSeller,
        ),
      ),
    );
  }

  void _handleItemIdNavigation(
      List<Map<String, dynamic>> products, String itemId) {
    print('Looking for item with ID: $itemId');
    print('Total products available: ${products.length}');
    
    // Find the product with the given itemId
    final product = products.firstWhere(
      (p) =>
          p['variants'] != null &&
          (p['variants'] as List).any((v) => v['id'] == itemId || v['globalId'] == itemId),
      orElse: () => {},
    );

    if (product.isNotEmpty) {
      print('Found product: ${product['name']}');
      // Open the product customization page immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Opening product customization for: ${product['name']}');
        _openItemCustomization(product);
      });
    } else {
      print('Product with ID $itemId not found');
      // Try to find by product ID directly (fallback)
      final directProduct = products.firstWhere(
        (p) => p['id'] == itemId,
        orElse: () => {},
      );
      
      if (directProduct.isNotEmpty) {
        print('Found product by direct ID: ${directProduct['name']}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openItemCustomization(directProduct);
        });
      }
    }
  }

  void _navigateToCategory(String categoryName) {
    print('Navigating to category: $categoryName');
    print('Available categories: $categories');

    // Find the index of the category in the categories list
    final categoryIndex = categories.indexWhere(
      (category) => category.toLowerCase() == categoryName.toLowerCase(),
    );

    if (categoryIndex != -1) {
      print('Found category at index: $categoryIndex');

      // Animate to the category tab
      if (_tabController.index != categoryIndex) {
        _tabController.animateTo(categoryIndex);
        print('Animated to tab: $categoryIndex');
      }

      // Also scroll to the category section
      final actualCategoryName = categories[categoryIndex];

      // Add a slight delay to ensure the tab animation completes and UI is rendered
      Future.delayed(const Duration(milliseconds: 300), () {
        print('Scrolling to category section: $actualCategoryName');
        _scrollToCategory(actualCategoryName);
      });
    } else {
      print('Category not found: $categoryName');
      // If exact match not found, try to find a partial match
      final partialMatch = categories.firstWhere(
        (category) =>
            category.toLowerCase().contains(categoryName.toLowerCase()),
        orElse: () => '',
      );

      if (partialMatch.isNotEmpty) {
        print('Found partial match: $partialMatch');
        final partialIndex = categories.indexOf(partialMatch);
        _tabController.animateTo(partialIndex);

        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToCategory(partialMatch);
        });
      }
    }
  }
}
