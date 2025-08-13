import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/address_prompt_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../features/address/pages/address_management_page.dart';

class AddressPromptBanner extends ConsumerWidget {
  final bool isDismissible;
  final String? customMessage;
  final VoidCallback? onDismiss;

  const AddressPromptBanner({
    super.key,
    this.isDismissible = true,
    this.customMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressPromptStateAsync = ref.watch(addressPromptStateProvider);

    return addressPromptStateAsync.when(
      loading: () => const SizedBox.shrink(), // Don't show while loading
      error: (error, stack) => const SizedBox.shrink(), // Don't show on error
      data: (promptState) {
        // Only show if user needs address
        if (promptState != AddressPromptState.needsAddress) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_location_alt,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customMessage ?? 'Add your delivery address',
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
                            'Add an address now to make ordering faster, or you can do it later when you\'re ready to order.',
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      ),
                    ),
                    if (isDismissible) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => onDismiss?.call(),
                        icon: Icon(
                          Icons.close,
                          color: const Color(0xFF757575),
                          size: 20,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToAddressPage(BuildContext context, WidgetRef ref) {
    // Navigator.of(context)
    //     .push(
    //   MaterialPageRoute(
    //     builder: (context) => const AddressManagementPage(),
    //   ),
    // )
    //     .then((_) {
    //   // Refresh address data when returning
    //   ref.invalidate(addressNotifierProvider);
    //   ref.invalidate(defaultAddressProvider);
    // });
    ref.invalidate(addressNotifierProvider);
    ref.invalidate(defaultAddressProvider);
    GoRouter.of(context).go('/addresses');
  }
}
