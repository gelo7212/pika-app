import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';
import '../di/service_locator.dart';

// Provider for AddressService
final addressServiceProvider = Provider<AddressService>((ref) {
  return serviceLocator<AddressService>();
});

// Provider for addresses list
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  final addressService = ref.read(addressServiceProvider);
  return await addressService.getAddresses();
});

// Provider for a specific address
final addressProvider = FutureProvider.family<Address, String>((ref, id) async {
  final addressService = ref.read(addressServiceProvider);
  return await addressService.getAddress(id);
});

// Provider for the default address
final defaultAddressProvider = FutureProvider<Address?>((ref) async {
  final addressService = ref.read(addressServiceProvider);
  return await addressService.getDefaultAddress();
});

// State notifier for managing address operations
class AddressNotifier extends StateNotifier<AsyncValue<List<Address>>> {
  final AddressService _addressService;
  final Ref _ref;

  AddressNotifier(this._addressService, this._ref) : super(const AsyncValue.loading()) {
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    state = const AsyncValue.loading();
    try {
      final addresses = await _addressService.getAddresses();
      state = AsyncValue.data(addresses);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createAddress({
    required String name,
    required String address,
    required double longitude,
    required double latitude,
    required String phone,
    bool isDefault = false,
  }) async {
    try {
      await _addressService.createAddress(
        name: name,
        address: address,
        longitude: longitude,
        latitude: latitude,
        phone: phone,
        isDefault: isDefault,
      );
      await loadAddresses(); // Refresh the list
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateAddress({
    required String id,
    required String name,
    required String address,
    required double longitude,
    required double latitude,
    required String phone,
    bool isDefault = false,
  }) async {
    try {
      await _addressService.updateAddress(
        id: id,
        name: name,
        address: address,
        longitude: longitude,
        latitude: latitude,
        phone: phone,
        isDefault: isDefault,
      );
      await loadAddresses(); // Refresh the list
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _addressService.deleteAddress(id);
      await loadAddresses(); // Refresh the list
    } catch (error) {
      rethrow;
    }
  }

  Future<void> setDefaultAddress(String id) async {
    try {
      await _addressService.setDefaultAddress(id);
      await loadAddresses(); // Refresh the list
      // Also invalidate the default address provider to refresh it
      _ref.invalidate(defaultAddressProvider);
    } catch (error) {
      rethrow;
    }
  }

  // Get default address
  Future<Address?> getDefaultAddress() async {
    try {
      final address = await _addressService.getDefaultAddress();
      return address;
    } catch (error) {
      rethrow;
    }
  }
}

// Provider for the address notifier
final addressNotifierProvider =
    StateNotifierProvider<AddressNotifier, AsyncValue<List<Address>>>((ref) {
  final addressService = ref.read(addressServiceProvider);
  return AddressNotifier(addressService, ref);
});
