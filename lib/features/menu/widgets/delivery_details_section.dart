import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/delivery_provider.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/delivery_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../address/pages/address_management_page.dart';

class DeliveryDetailsSection extends ConsumerStatefulWidget {
  const DeliveryDetailsSection({super.key});

  @override
  ConsumerState<DeliveryDetailsSection> createState() => _DeliveryDetailsSectionState();
}

class _DeliveryDetailsSectionState extends ConsumerState<DeliveryDetailsSection> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _orderCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deliveryDetails = ref.read(deliveryProvider);
      _contactController.text = deliveryDetails.contactNumber;
      _orderCommentController.text = deliveryDetails.orderComment ?? '';
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    _orderCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deliveryDetails = ref.watch(deliveryProvider);
    final deliveryNotifier = ref.read(deliveryProvider.notifier);
    final defaultAddressAsync = ref.watch(defaultAddressProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Text(
            'Delivery Details',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),

          // Address Section
          _buildAddressSection(context, theme, deliveryDetails, deliveryNotifier, defaultAddressAsync),

          const SizedBox(height: 16),

          // Contact Number
          Text(
            'Contact Number',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            onChanged: (value) => deliveryNotifier.updateContactNumber(value),
            decoration: InputDecoration(
              hintText: 'Enter contact number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Order Comment
          Text(
            'Order Comment',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _orderCommentController,
            maxLines: 3,
            onChanged: (value) => deliveryNotifier.updateOrderComment(value.isEmpty ? null : value),
            decoration: InputDecoration(
              hintText: 'Add any special instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(
    BuildContext context,
    ThemeData theme,
    DeliveryDetails deliveryDetails,
    DeliveryNotifier deliveryNotifier,
    AsyncValue<Address?> defaultAddressAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delivery Address',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToAddressPage(context),
              child: const Text('Change'),
            ),
          ],
        ),
        
        const SizedBox(height: 8),

        defaultAddressAsync.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading address...'),
            ],
          ),
          error: (error, stack) => _buildNoAddressRow(context, theme),
          data: (defaultAddress) {
            if (defaultAddress == null) {
              return _buildNoAddressRow(context, theme);
            }

            // Auto-select default address and fill contact number
            if (!deliveryDetails.hasAddress) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                deliveryNotifier.updateAddressId(defaultAddress.id);
                deliveryNotifier.updateAddress(defaultAddress.address);
                // Auto-fill contact number from address if empty
                if (deliveryDetails.contactNumber.isEmpty && defaultAddress.phone.isNotEmpty) {
                  deliveryNotifier.updateContactNumber(defaultAddress.phone);
                  _contactController.text = defaultAddress.phone;
                }
              });
            }

            return _buildAddressRow(context, theme, defaultAddress);
          },
        ),
      ],
    );
  }

  Widget _buildNoAddressRow(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.warning_outlined,
          color: Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No delivery address found',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.red[700],
            ),
          ),
        ),
        TextButton(
          onPressed: () => _showAddAddressModal(context),
          child: const Text('Add Address'),
        ),
      ],
    );
  }

  Widget _buildAddressRow(BuildContext context, ThemeData theme, Address address) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address.address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToAddressPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddressManagementPage(),
      ),
    ).then((_) {
      // Refresh address data when returning
      ref.invalidate(defaultAddressProvider);
    });
  }

  void _showAddAddressModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Delivery Address'),
        content: const Text(
          'Please add a delivery address to continue with your order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAddressPage(context);
            },
            child: const Text('Add Address'),
          ),
        ],
      ),
    );
  }
}
