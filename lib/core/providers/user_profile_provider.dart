import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user-profile-model.dart';
import '../services/address_service.dart';
import '../di/service_locator.dart';

// Provider for user profile data
final userProfileProvider = FutureProvider<UserProfileModel>((ref) async {
  final addressService = serviceLocator<AddressService>();
  return await addressService.userProfile();
});

// State notifier for managing user profile operations
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfileModel>> {
  final AddressService _addressService;

  UserProfileNotifier(this._addressService) : super(const AsyncValue.loading()) {
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    state = const AsyncValue.loading();
    try {
      final userProfile = await _addressService.userProfile();
      state = AsyncValue.data(userProfile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshUserProfile() async {
    await loadUserProfile();
  }
}

// Provider for the user profile state notifier
final userProfileNotifierProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfileModel>>((ref) {
  final addressService = serviceLocator<AddressService>();
  return UserProfileNotifier(addressService);
});
