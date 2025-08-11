import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/auth_interface.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

/// Service responsible for background token validation and management
class TokenValidationService {
  static TokenValidationService? _instance;
  static TokenValidationService get instance {
    _instance ??= TokenValidationService._();
    return _instance!;
  }

  TokenValidationService._();

  Timer? _validationTimer;
  bool _isValidating = false;
  DateTime? _lastValidation;
  
  // Validation interval - check every 5 minutes
  static const Duration _validationInterval = Duration(minutes: 5);

  final AuthInterface _authService = serviceLocator<AuthInterface>();
  final TokenServiceInterface _tokenService = serviceLocator<TokenServiceInterface>();

  /// Start background token validation
  void startBackgroundValidation() {
    if (_validationTimer?.isActive == true) {
      return; // Already running
    }

    debugPrint('TokenValidationService: Starting background validation');
    
    // Run initial validation
    _validateTokenInBackground();
    
    // Set up periodic validation
    _validationTimer = Timer.periodic(_validationInterval, (_) {
      _validateTokenInBackground();
    });
  }

  /// Stop background token validation
  void stopBackgroundValidation() {
    debugPrint('TokenValidationService: Stopping background validation');
    _validationTimer?.cancel();
    _validationTimer = null;
    _isValidating = false;
  }

  /// Validate token in background (non-blocking)
  void _validateTokenInBackground() {
    if (_isValidating) {
      debugPrint('TokenValidationService: Validation already in progress');
      return;
    }

    unawaited(_performTokenValidation());
  }

  /// Perform the actual token validation
  Future<void> _performTokenValidation() async {
    _isValidating = true;
    _lastValidation = DateTime.now();

    try {
      debugPrint('TokenValidationService: Validating token...');
      
      final tokens = await _tokenService.getStoredTokens();
      if (tokens == null) {
        debugPrint('TokenValidationService: No tokens found');
        return;
      }

      // Check if token is valid
      final isValid = await _tokenService.validateToken(tokens.userAccessToken);
      
      if (!isValid) {
        debugPrint('TokenValidationService: Token invalid, attempting refresh...');
        
        try {
          // Try to refresh the token
          await _authService.refreshToken();
          debugPrint('TokenValidationService: Token refreshed successfully');
        } catch (e) {
          debugPrint('TokenValidationService: Token refresh failed: $e');
          // Token refresh failed - user needs to re-authenticate
          await _handleTokenRefreshFailure();
        }
      } else {
        debugPrint('TokenValidationService: Token is valid');
      }
    } catch (e) {
      debugPrint('TokenValidationService: Validation error: $e');
    } finally {
      _isValidating = false;
    }
  }

  /// Handle token refresh failure
  Future<void> _handleTokenRefreshFailure() async {
    try {
      debugPrint('TokenValidationService: Handling token refresh failure');
      
      // Clear invalid tokens
      await _tokenService.clearTokens();
      
      // You could implement additional logic here like:
      // - Showing a notification to the user
      // - Triggering a logout event
      // - Redirecting to login page
      
    } catch (e) {
      debugPrint('TokenValidationService: Error handling token refresh failure: $e');
    }
  }

  /// Force an immediate token validation (blocking)
  Future<bool> validateTokenNow() async {
    if (_isValidating) {
      // Wait for current validation to complete
      while (_isValidating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    try {
      debugPrint('TokenValidationService: Force validating token...');
      return await _authService.validateAndRefreshToken();
    } catch (e) {
      debugPrint('TokenValidationService: Force validation error: $e');
      return false;
    }
  }

  /// Check if a validation is currently in progress
  bool get isValidating => _isValidating;

  /// Get the last validation time
  DateTime? get lastValidation => _lastValidation;

  /// Check if we need to validate (based on last validation time)
  bool get needsValidation {
    if (_lastValidation == null) return true;
    
    final timeSinceLastValidation = DateTime.now().difference(_lastValidation!);
    return timeSinceLastValidation >= _validationInterval;
  }

  /// Dispose of the service
  void dispose() {
    stopBackgroundValidation();
    _instance = null;
  }
}

/// Extension to avoid awaiting futures in fire-and-forget scenarios
extension Unawaited on Future<void> {
  void get unawaited => {};
}
