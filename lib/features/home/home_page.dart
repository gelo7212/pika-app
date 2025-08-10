import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/home_data_provider.dart';
import '../../shared/widgets/home_order_timeline_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  // Category icon mapping for fallbacks
  static const Map<String, IconData> _categoryIconMap = {
    'Coffee': Icons.local_cafe,
    'coffee': Icons.local_cafe,
    'Frappe': Icons.local_drink,
    'frappe': Icons.local_drink,
    'Refresher': Icons.emoji_food_beverage,
    'refresher': Icons.emoji_food_beverage,
    'Pastry': Icons.cake,
    'pastry': Icons.cake,
    'Tea': Icons.emoji_food_beverage,
    'tea': Icons.emoji_food_beverage,
    'Sandwich': Icons.lunch_dining,
    'sandwich': Icons.lunch_dining,
    'Salad': Icons.eco,
    'salad': Icons.eco,
    'Dessert': Icons.cake,
    'dessert': Icons.cake,
    'Snack': Icons.fastfood,
    'snack': Icons.fastfood,
    'Breakfast': Icons.free_breakfast,
    'breakfast': Icons.free_breakfast,
  };

  // Get icon for category name with fallback
  static IconData _getIconForCategory(String categoryName) {
    // Try exact match first
    IconData? icon = _categoryIconMap[categoryName];
    if (icon != null) return icon;

    // Try lowercase match
    icon = _categoryIconMap[categoryName.toLowerCase()];
    if (icon != null) return icon;

    // Try partial matches for common keywords
    final lowerName = categoryName.toLowerCase();
    if (lowerName.contains('coffee')) return Icons.local_cafe;
    if (lowerName.contains('tea')) return Icons.emoji_food_beverage;
    if (lowerName.contains('frappe') || lowerName.contains('drink'))
      return Icons.local_drink;
    if (lowerName.contains('pastry') ||
        lowerName.contains('cake') ||
        lowerName.contains('dessert')) return Icons.cake;
    if (lowerName.contains('sandwich') || lowerName.contains('lunch'))
      return Icons.lunch_dining;
    if (lowerName.contains('salad')) return Icons.eco;
    if (lowerName.contains('snack')) return Icons.fastfood;
    if (lowerName.contains('breakfast')) return Icons.free_breakfast;

    // Default fallback
    return Icons.category;
  }

  // Get greeting based on current time
  String _getGreetingBasedOnTime() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning!';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon!';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening!';
    } else if (hour >= 0 && hour < 5) {
      return 'Late night snack time!';
    } else if (hour >= 21 && hour < 24) {
      return 'Late night treat time!';
    } else {
      return 'Good night!';
    }
  }

  // Get random message based on current time
  String _getRandomMessageBasedOnTime() {
    final now = DateTime.now();
    final hour = now.hour;

    // Create lists of messages for different times of day
    List<String> messages;

    if (hour >= 5 && hour < 12) {
      // Morning messages - focus on coffee and breakfast drinks
      messages = [
        'Ready for your morning coffee?',
        'How about a fresh latte to start your day?',
        'Craving a matcha latte this morning?',
        'What coffee would you like today?',
        'Time for your daily caffeine fix?',
        'Ready for a hot coffee or refresher?',
      ];
    } else if (hour >= 12 && hour < 17) {
      // Afternoon messages - focus on refreshers and iced drinks
      messages = [
        'Need an afternoon refresher?',
        'How about a cool frappe to beat the heat?',
        'Craving an iced coffee or soda?',
        'Ready for a refreshing drink?',
        'Time for a matcha frappe?',
        'What refresher sounds good right now?',
        'Need a pick-me-up drink and snack?',
      ];
    } else if (hour >= 17 && hour < 21) {
      // Evening messages - focus on treats and lighter options
      messages = [
        'Ready for an evening treat?',
        'How about a sweet frappe or snack?',
        'Craving something refreshing tonight?',
        'Time for a relaxing drink?',
        'Want a soda or light snack?',
        'Ready for your evening refresher?',
        'How about a matcha drink to unwind?',
      ];
    } else {
      // Night messages - focus on lighter options and snacks
      messages = [
        'Craving a late-night refresher?',
        'How about a soda or light snack?',
        'Ready for a refreshing drink?',
        'Want something light and tasty?',
        'Time for a cool drink or snack?',
        'Craving a frappe or refresher?',
      ];
    }

    // Return a random message from the appropriate list
    return messages[DateTime.now().millisecond % messages.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedInAsync = ref.watch(isLoggedInProvider);

    return isLoggedInAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildUnauthenticatedHome(context),
      data: (isLoggedIn) {
        return isLoggedIn
            ? _buildAuthenticatedHome(context, ref)
            : _buildUnauthenticatedHome(context);
      },
    );
  }

  Widget _buildAuthenticatedHome(BuildContext context, WidgetRef ref) {
    final nearestStoreAsync = ref.watch(nearestStoreWithRefreshProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting and store info
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreetingBasedOnTime(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF757575),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getRandomMessageBasedOnTime(),
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        // Refresh button
                        IconButton(
                          onPressed: () {
                            // Trigger refresh by incrementing the refresh counter
                            ref
                                .read(refreshNearestStoreProvider.notifier)
                                .state++;
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          tooltip: 'Refresh nearest store',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Store information - conversational style
                    nearestStoreAsync.when(
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.orange[600],
                                  ),
                            ),
                          ),
                        ],
                      ),
                      data: (storeData) {
                        if (storeData.store != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 14,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF757575),
                                            ),
                                        children: [
                                          const TextSpan(
                                              text: 'Delivering from '),
                                          TextSpan(
                                            text: storeData.store!.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (storeData.usedCurrentLocation)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 20, top: 2),
                                  child: Text(
                                    '• Based on your current location',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF999999),
                                          fontSize: 11,
                                        ),
                                  ),
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
                              Text(
                                'No delivery available in your area yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF999999),
                                    ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // AI-powered Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _openAIAssist(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ask AI what to order today',
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Get personalized drink recommendations ✨',
                                style: TextStyle(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.primary,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Featured Items Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Featured',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              _buildFeaturedItems(context, ref),

              const SizedBox(height: 32),

              // Special Offers Section
              _buildSpecialOffers(context, ref),

              const SizedBox(height: 32),

              // Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuPreview(context, ref),

              const SizedBox(height: 32),

              // Advertisements Section
              _buildAdvertisements(context, ref),

              const SizedBox(height: 100), // Space for floating action button
            ],
          ),
        ),
      ),
      // Order timeline positioned at bottom, above navigation
      bottomSheet: const HomeOrderTimelineWidget(),
    );
  }

  Widget _buildFeaturedItems(BuildContext context, WidgetRef ref) {
    final featuredItems = ref.watch(featuredItemsProvider);

    if (featuredItems.isEmpty) {
      return _buildFeaturedItemsPlaceholder(context);
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: featuredItems.length,
        itemBuilder: (context, index) {
          final item = featuredItems[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E5E5),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => context
                  .go('/menu?item=${item.id}'), // Navigate to menu with item ID
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      color: const Color(0xFFF5F5F5),
                    ),
                    child: item.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Image.network(
                              _convertGoogleDriveUrl(item.image),
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: const Color(0xFF757575),
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                child: Icon(
                                  Icons.restaurant_outlined,
                                  size: 24,
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 24,
                              color: const Color(0xFF757575),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${item.price.toStringAsFixed(0)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
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
        },
      ),
    );
  }

  Widget _buildFeaturedItemsPlaceholder(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E5E5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    color: const Color(0xFFF5F5F5),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_outlined,
                      size: 24,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured ${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${(index + 1) * 50}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuPreview(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    // Debug: Print category loading status
    print('Categories loaded: ${categories.length} items');
    for (final category in categories) {
      print('Category: ${category.name}, Image: ${category.image}');
    }

    if (categories.isEmpty) {
      print('Warning: Categories are empty, showing placeholder');
      return _buildMenuPreviewPlaceholder(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive columns based on screen width
          int crossAxisCount = 2; // Default for small screens
          double itemHeight = 100;

          if (constraints.maxWidth > 600) {
            // Tablet/Web layout
            crossAxisCount = 4;
            itemHeight = 120;
          } else if (constraints.maxWidth > 400) {
            // Large phone layout
            crossAxisCount = 3;
            itemHeight = 110;
          }

          // Calculate spacing to utilize available width efficiently
          double totalSpacing = (crossAxisCount - 1) * 16;
          double availableWidth = constraints.maxWidth - totalSpacing;
          double calculatedItemWidth = availableWidth / crossAxisCount;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: calculatedItemWidth / itemHeight,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryColor = _getColorFromHex(category.color);

              return GestureDetector(
                onTap: () => context.go(category.link),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5E5E5),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: constraints.maxWidth > 600 ? 56 : 48,
                          height: constraints.maxWidth > 600 ? 56 : 48,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: category.image.isNotEmpty
                              ? _buildCategoryImage(
                                  category.image,
                                  constraints.maxWidth > 600 ? 56 : 48,
                                  categoryColor,
                                  constraints,
                                  categoryName: category.name,
                                )
                              : Icon(
                                  _getIconForCategory(category.name),
                                  size: constraints.maxWidth > 600 ? 28 : 24,
                                  color: categoryColor,
                                ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            category.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize:
                                      constraints.maxWidth > 600 ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMenuPreviewPlaceholder(BuildContext context) {
    // Use the same categories as in JSON for consistency
    final placeholderCategories = [
      {
        'name': 'Coffee',
        'icon': Icons.local_cafe,
        'color': '#8B4513',
        'link': '/menu?category=coffee'
      },
      {
        'name': 'Frappe',
        'icon': Icons.local_drink,
        'color': '#4A90E2',
        'link': '/menu?category=frappe'
      },
      {
        'name': 'Refresher',
        'icon': Icons.emoji_food_beverage,
        'color': '#7ED321',
        'link': '/menu?category=refresher'
      },
      {
        'name': 'Pastry',
        'icon': Icons.cake,
        'color': '#7ED321',
        'link': '/menu?category=pastry'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive columns based on screen width
          int crossAxisCount = 2; // Default for small screens
          double itemHeight = 100;

          if (constraints.maxWidth > 600) {
            // Tablet/Web layout
            crossAxisCount = 4;
            itemHeight = 120;
          } else if (constraints.maxWidth > 400) {
            // Large phone layout
            crossAxisCount = 3;
            itemHeight = 110;
          }

          // Calculate spacing to utilize available width efficiently
          double totalSpacing = (crossAxisCount - 1) * 16;
          double availableWidth = constraints.maxWidth - totalSpacing;
          double calculatedItemWidth = availableWidth / crossAxisCount;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: calculatedItemWidth / itemHeight,
            ),
            itemCount: placeholderCategories.length,
            itemBuilder: (context, index) {
              final category = placeholderCategories[index];
              final categoryColor =
                  _getColorFromHex(category['color'] as String);
              return GestureDetector(
                onTap: () => context.go('/menu'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(
                          0.3), // Red border to indicate placeholder
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: constraints.maxWidth > 600 ? 56 : 48,
                          height: constraints.maxWidth > 600 ? 56 : 48,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            size: constraints.maxWidth > 600 ? 28 : 24,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Column(
                            children: [
                              Text(
                                category['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontSize:
                                          constraints.maxWidth > 600 ? 14 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '(Placeholder)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.red,
                                      fontSize: 8,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUnauthenticatedHome(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF757575),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pika - ESBI Delivery',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover delicious food and place orders with ease',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF757575),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Featured content preview (disabled state)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Featured Items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewFeaturedItems(context),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Menu categories preview (disabled state)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewMenuCategories(context),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Call to action message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sign in to start ordering',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account or sign in to browse our full menu, customize your orders, and track your delivery.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF757575),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 120), // Space for bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
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
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPreviewFeaturedItems(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E5E5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_outlined,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewMenuCategories(BuildContext context) {
    final categories = [
      {'name': 'Coffee', 'icon': Icons.local_cafe},
      {'name': 'Frappe', 'icon': Icons.local_drink},
      {'name': 'Refresher', 'icon': Icons.emoji_food_beverage},
      {'name': 'Pastry', 'icon': Icons.cake},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive columns based on screen width
        int crossAxisCount = 2; // Default for small screens
        double itemHeight = 100;

        if (constraints.maxWidth > 600) {
          // Tablet/Web layout
          crossAxisCount = 4;
          itemHeight = 120;
        } else if (constraints.maxWidth > 400) {
          // Large phone layout
          crossAxisCount = 3;
          itemHeight = 110;
        }

        // Calculate spacing to utilize available width efficiently
        double totalSpacing = (crossAxisCount - 1) * 16;
        double availableWidth = constraints.maxWidth - totalSpacing;
        double calculatedItemWidth = availableWidth / crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: calculatedItemWidth / itemHeight,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: constraints.maxWidth > 600 ? 56 : 48,
                      height: constraints.maxWidth > 600 ? 56 : 48,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category['icon'] as IconData,
                        size: constraints.maxWidth > 600 ? 28 : 24,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        category['name'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey,
                              fontSize: constraints.maxWidth > 600 ? 14 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpecialOffers(BuildContext context, WidgetRef ref) {
    final specialOffers = ref.watch(specialOffersProvider);
    specialOffers.clear();

    // if (specialOffers.isEmpty) {
    //   return _buildDefaultSpecialOffer(context);
    // }

    return Column(
      children: specialOffers
          .map((offer) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.properties['value'] ?? offer.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer.details,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () => context.go('/menu'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                ),
                                child: const Text('Order now'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.local_offer_outlined,
                        size: 32,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDefaultSpecialOffer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '20% OFF',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'First order special',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => context.go('/menu'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('Order now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.local_offer_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvertisements(BuildContext context, WidgetRef ref) {
    final advertisements = ref.watch(advertisementsProvider);

    if (advertisements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'What\'s New',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        ...advertisements
            .map((ad) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        final link = ad.properties['link'];
                        if (link != null && link.toString().isNotEmpty) {
                          // Handle navigation based on link
                          if (link.toString().startsWith('/')) {
                            context.go(link.toString());
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ad.details,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF757575),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: const Color(0xFF757575),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ],
    );
  }

  // Navigation methods
  void _openAIAssist(BuildContext context) {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    // Navigate to AI Assistant page
    context.go('/ai-assist');
  }

  // Helper methods
  bool _isNetworkImage(String imagePath) {
    return imagePath.startsWith('http://') || imagePath.startsWith('https://');
  }

  String _convertGoogleDriveUrl(String url) {
    // Convert Google Drive sharing URLs to direct image URLs
    if (url.contains('drive.google.com/file/d/')) {
      // Extract file ID from the sharing URL
      final regex = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
      final match = regex.firstMatch(url);
      if (match != null) {
        final fileId = match.group(1);
        return 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }
    return url; // Return original URL if it's not a Google Drive sharing link
  }

  Widget _buildCategoryImage(String imagePath, double size, Color fallbackColor,
      BoxConstraints constraints,
      {String? categoryName}) {
    // Get the appropriate fallback icon for this category
    final fallbackIcon = categoryName != null
        ? _getIconForCategory(categoryName)
        : Icons.category;

    if (imagePath.isEmpty) {
      return Icon(
        fallbackIcon,
        size: constraints.maxWidth > 600 ? 28 : 24,
        color: fallbackColor,
      );
    }

    if (_isNetworkImage(imagePath)) {
      final processedUrl = _convertGoogleDriveUrl(imagePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          processedUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fallbackColor.withOpacity(0.6),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Failed to load category image for $categoryName: $error');
            return Icon(
              fallbackIcon,
              size: constraints.maxWidth > 600 ? 28 : 24,
              color: fallbackColor,
            );
          },
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print(
                'Failed to load category asset image for $categoryName: $error');
            return Icon(
              fallbackIcon,
              size: constraints.maxWidth > 600 ? 28 : 24,
              color: fallbackColor,
            );
          },
        ),
      );
    }
  }

  Color _getColorFromHex(String hexColor) {
    try {
      // Remove the # if present
      final hex = hexColor.replaceAll('#', '');
      // Parse the hex string to integer and create Color
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      // Return a default color if parsing fails
      return const Color(0xFF6B73FF);
    }
  }
}
