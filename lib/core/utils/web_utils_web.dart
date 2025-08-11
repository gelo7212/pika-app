// Web implementation for web utilities
import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

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

  /// Checks if the browser is compatible with Google Sign-In
  static bool get isGoogleSignInCompatible {
    if (!kIsWeb) return true;
    try {
      final userAgent = web.window.navigator.userAgent;
      
      // Check for known incompatible browsers or configurations
      if (userAgent.contains('Chrome')) return true;
      if (userAgent.contains('Firefox')) return true;
      if (userAgent.contains('Edge')) return true;
      
      // Safari can work but may have issues with ID tokens
      if (isSafari) {
        if (kDebugMode) {
          print('Safari detected - Google Sign-In may have token limitations');
        }
        return true; // Still allow, but with warnings
      }
      
      return true; // Default to compatible
    } catch (e) {
      return true; // Default to compatible if check fails
    }
  }

  /// Gets browser-specific recommendations for authentication
  static String get authRecommendation {
    if (!kIsWeb) return '';
    try {
      if (isSafari) {
        return 'For best results with Safari, ensure third-party cookies are enabled and disable content blockers during sign-in.';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Checks if Facebook SDK is ready
  static bool get isFacebookReady {
    if (!kIsWeb) return false;
    try {
      // Check if FB object exists and fbReady flag is set
      final hasFbProperty = js_util.hasProperty(web.window, 'FB');
      final hasFbReadyProperty = js_util.hasProperty(web.window, 'fbReady');
      final fbReady = hasFbReadyProperty ? js_util.getProperty(web.window, 'fbReady') == true : false;
      
      return hasFbProperty && fbReady;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Facebook readiness: $e');
      }
      return false;
    }
  }

  /// Waits for Facebook SDK to be ready
  static Future<void> waitForFacebookSDK() async {
    if (!kIsWeb) return;

    // If already ready, return immediately
    if (isFacebookReady) return;

    // Add debug logging
    if (kDebugMode) {
      print('Waiting for Facebook SDK to load...');
    }

    // Wait for both FB object and fbReady flag
    int attempts = 0;
    const maxAttempts = 100; // 10 seconds with 100ms intervals

    while (attempts < maxAttempts && !isFacebookReady) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      if (kDebugMode && attempts % 20 == 0) {
        print('Still waiting for Facebook SDK... attempt $attempts');
      }
    }

    if (!isFacebookReady) {
      throw Exception('Facebook SDK failed to initialize within timeout');
    }

    if (kDebugMode) {
      print('Facebook SDK is ready and functional');
    }
  }
}
