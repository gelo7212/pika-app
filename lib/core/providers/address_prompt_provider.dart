import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';

/// Provider to check if user should be prompted about addresses
final shouldPromptAddressProvider = FutureProvider<bool>((ref) async {
  // First check if user is logged in
  final isLoggedInAsync = ref.watch(isLoggedInProvider);
  
  return isLoggedInAsync.when(
    data: (isLoggedIn) async {
      if (!isLoggedIn) return false;
      
      // Check if user has any addresses
      try {
        final addressesAsync = ref.watch(addressNotifierProvider);
        return addressesAsync.when(
          data: (addresses) => addresses.isEmpty,
          loading: () => false,
          error: (_, __) => false,
        );
      } catch (e) {
        return false;
      }
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to check if user needs to set a default address
final shouldPromptDefaultAddressProvider = FutureProvider<bool>((ref) async {
  // First check if user is logged in
  final isLoggedInAsync = ref.watch(isLoggedInProvider);
  
  return isLoggedInAsync.when(
    data: (isLoggedIn) async {
      if (!isLoggedIn) return false;
      
      try {
        // Check addresses and default address in parallel
        final addressesAsync = ref.watch(addressNotifierProvider);
        final defaultAddressAsync = ref.watch(defaultAddressProvider);
        
        return addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) return false; // No addresses at all
            
            return defaultAddressAsync.when(
              data: (defaultAddress) => defaultAddress == null, // Has addresses but no default
              loading: () => false,
              error: (_, __) => false,
            );
          },
          loading: () => false,
          error: (_, __) => false,
        );
      } catch (e) {
        return false;
      }
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Combined provider for address prompt state
final addressPromptStateProvider = FutureProvider<AddressPromptState>((ref) async {
  final shouldPromptAddress = await ref.watch(shouldPromptAddressProvider.future);
  final shouldPromptDefault = await ref.watch(shouldPromptDefaultAddressProvider.future);
  
  if (shouldPromptAddress) {
    return AddressPromptState.needsAddress;
  } else if (shouldPromptDefault) {
    return AddressPromptState.needsDefaultAddress;
  } else {
    return AddressPromptState.none;
  }
});

enum AddressPromptState {
  none,
  needsAddress,
  needsDefaultAddress,
}
