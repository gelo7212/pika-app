// Web implementation for web utilities
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Web utilities for browser-specific functionality
class WebUtils {
  /// Detects if the current browser is Safari
  static bool get isSafari {
    if (!kIsWeb) return false;
    try {
      return web.window.navigator.userAgent.contains('Safari') &&
             !web.window.navigator.userAgent.contains('Chrome');
    } catch (e) {
      return false;
    }
  }

  /// Gets the user agent string
  static String get userAgent {
    if (!kIsWeb) return '';
    try {
      return web.window.navigator.userAgent;
    } catch (e) {
      return '';
    }
  }

  /// Checks if the browser supports certain features
  static bool get supportsPopups {
    if (!kIsWeb) return false;
    try {
      // Safari has stricter popup policies
      return !isSafari;
    } catch (e) {
      return false;
    }
  }

  /// Checks if Facebook SDK is ready
  static bool get isFacebookReady {
    if (!kIsWeb) return false;
    try {
      // Check if FB object exists on window
      final dynamic window = web.window;
      return window['FB'] != null && window['fbReady'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Waits for Facebook SDK to be ready
  static Future<void> waitForFacebookSDK() async {
    if (!kIsWeb) return;
    
    // If already ready, return immediately
    if (isFacebookReady) return;
    
    // Poll for Facebook SDK readiness with timeout
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds with 100ms intervals
    
    while (attempts < maxAttempts && !isFacebookReady) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (!isFacebookReady) {
      throw Exception('Facebook SDK failed to load within timeout');
    }
  }
}
