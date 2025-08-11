// Stub implementation for non-web platforms (iOS, Android)

/// Web utilities stub for mobile platforms
class WebUtils {
  /// Always returns false on mobile platforms
  static bool get isSafari => false;

  /// Returns empty string on mobile platforms
  static String get userAgent => '';

  /// Always returns true on mobile platforms (no popup restrictions)
  static bool get supportsPopups => true;

  /// Always returns true on mobile platforms (Google Sign-In works well on mobile)
  static bool get isGoogleSignInCompatible => true;

  /// Returns empty string on mobile platforms (no browser-specific recommendations needed)
  static String get authRecommendation => '';

  /// Always returns true on mobile platforms (no Facebook SDK needed)
  static bool get isFacebookReady => true;

  /// No-op on mobile platforms
  static Future<void> waitForFacebookSDK() async {}
}
