import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/auth_interface.dart';
import '../di/service_locator.dart';

// Auth state model
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final bool isValidating;
  final DateTime lastValidated;

  const AuthState({
    required this.isAuthenticated,
    this.token,
    this.isValidating = false,
    required this.lastValidated,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    bool? isValidating,
    DateTime? lastValidated,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      isValidating: isValidating ?? this.isValidating,
      lastValidated: lastValidated ?? this.lastValidated,
    );
  }
}

// Auth state notifier with background token validation
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthInterface _authService;
  Timer? _validationTimer;
  static const Duration _validationInterval = Duration(minutes: 5); // Check every 5 minutes

  AuthStateNotifier(this._authService)
      : super(AuthState(
          isAuthenticated: false,
          lastValidated: DateTime.now(),
        )) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _validateToken();
    _startBackgroundValidation();
  }

  void _startBackgroundValidation() {
    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(_validationInterval, (_) {
      _validateToken();
    });
  }

  Future<void> _validateToken() async {
    if (state.isValidating) return;

    state = state.copyWith(isValidating: true);

    try {
      final isValid = await _authService.validateAndRefreshToken();
      final token = await _authService.getCurrentUserToken();
      
      state = state.copyWith(
        isAuthenticated: isValid && token != null,
        token: token,
        isValidating: false,
        lastValidated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        token: null,
        isValidating: false,
        lastValidated: DateTime.now(),
      );
    }
  }

  Future<void> refreshAuth() async {
    await _validateToken();
  }

  Future<void> logout() async {
    _validationTimer?.cancel();
    try {
      await _authService.logout();
    } catch (e) {
      // Log error but continue with logout
      debugPrint('Auth service logout error: $e');
    }
    state = AuthState(
      isAuthenticated: false,
      lastValidated: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    super.dispose();
  }
}

// Main auth state provider with background validation
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = serviceLocator<AuthInterface>();
  return AuthStateNotifier(authService);
});

// Legacy providers for backward compatibility
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated;
});

// Provider for getting current user token
final currentUserTokenProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.token;
});

// Provider for auth service instance
final authServiceProvider = Provider<AuthInterface>((ref) {
  return serviceLocator<AuthInterface>();
});

// Provider for checking if token validation is in progress
final isTokenValidatingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isValidating;
});

// Provider for last validation time
final lastTokenValidationProvider = Provider<DateTime>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.lastValidated;
});
