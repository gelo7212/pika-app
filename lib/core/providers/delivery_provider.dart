import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/delivery_model.dart';

class DeliveryNotifier extends StateNotifier<DeliveryDetails> {
  static const String _storageKey = 'delivery_details';
  static const _storage = FlutterSecureStorage();

  DeliveryNotifier() : super(const DeliveryDetails(contactNumber: '')) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null) {
        final data = jsonDecode(stored);
        state = DeliveryDetails.fromJson(data);
      }
    } catch (e) {
      // Handle error silently
      print('Failed to load delivery details: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(state.toJson()),
      );
    } catch (e) {
      print('Failed to save delivery details: $e');
    }
  }

  Future<void> updateAddressId(String? addressId) async {
    state = state.copyWith(selectedAddressId: addressId);
    await _saveToStorage();
  }

  Future<void> updateAddress(String? address) async {
    state = state.copyWith(address: address);
    await _saveToStorage();
  }

  Future<void> updateContactNumber(String contactNumber) async {
    state = state.copyWith(contactNumber: contactNumber);
    await _saveToStorage();
  }

  Future<void> updateDeliveryNotes(String? notes) async {
    state = state.copyWith(deliveryNotes: notes);
    await _saveToStorage();
  }

  Future<void> updateCustomerName(String? name) async {
    state = state.copyWith(customerName: name);
    await _saveToStorage();
  }

  Future<void> updateOrderComment(String? comment) async {
    state = state.copyWith(orderComment: comment);
    await _saveToStorage();
  }

  Future<void> updateDetails(DeliveryDetails details) async {
    state = details;
    await _saveToStorage();
  }

  void clearDetails() {
    state = const DeliveryDetails(contactNumber: '');
    _storage.delete(key: _storageKey);
  }
}

// Provider instances
final deliveryProvider = StateNotifierProvider<DeliveryNotifier, DeliveryDetails>((ref) {
  return DeliveryNotifier();
});
