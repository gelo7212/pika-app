import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/auth_interface.dart';
import '../di/service_locator.dart';

// Provider for checking if user is logged in
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  try {
    final authService = serviceLocator<AuthInterface>();
    return await authService.isLoggedIn();
  } catch (e) {
    return false;
  }
});

// Provider for getting current user token
final currentUserTokenProvider = FutureProvider<String?>((ref) async {
  try {
    final authService = serviceLocator<AuthInterface>();
    return await authService.getCurrentUserToken();
  } catch (e) {
    return null;
  }
});

// Provider for auth service instance
final authServiceProvider = Provider<AuthInterface>((ref) {
  return serviceLocator<AuthInterface>();
});
