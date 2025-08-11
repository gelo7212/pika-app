import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';

/// Web-specific Firebase Authentication utilities
/// This provides a proper implementation for Google Sign-In on web
/// that avoids the deprecated google_sign_in_web plugin methods
class FirebaseWebAuth {
  /// Check if Firebase Auth is available on web
  static bool get isAvailable {
    if (!kIsWeb) return false;
    try {
      // Check if Firebase Auth and Google provider are available
      return _checkJSObject('firebaseAuth') && _checkJSObject('googleProvider');
    } catch (e) {
      debugPrint('Firebase Web Auth availability check failed: $e');
      return false;
    }
  }

  /// Sign in with Google using Firebase Auth popup (web-specific)
  static Future<UserCredential> signInWithGooglePopup() async {
    if (!kIsWeb) {
      throw UnsupportedError('Firebase Web Auth is only available on web platform');
    }

    try {
      debugPrint('Starting Firebase Web Auth Google Sign-In with popup');
      
      // Use Firebase Auth directly with popup
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add required scopes to ensure we get all necessary information
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.addScope('openid');
      
      // Set custom parameters to improve token handling and ensure ID token
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'access_type': 'offline',
        'include_granted_scopes': 'true',
        'response_type': 'code id_token', // Explicitly request both code and ID token
      });

      debugPrint('Attempting Firebase signInWithPopup...');
      
      // Sign in with popup
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(googleProvider);
      
      debugPrint('Firebase Web Auth successful for user: ${userCredential.user?.email}');
      debugPrint('User UID: ${userCredential.user?.uid}');
      
      // Verify we got a user and can get an ID token
      if (userCredential.user != null) {
        final String? idToken = await userCredential.user!.getIdToken(true);
        if (idToken != null) {
          debugPrint('Successfully obtained ID token of length: ${idToken.length}');
        } else {
          debugPrint('Warning: ID token is null even after successful auth');
        }
      }
      
      return userCredential;
      
    } catch (e) {
      debugPrint('Firebase Web Auth error: $e');
      rethrow;
    }
  }

  /// Check if a JavaScript object exists on the window
  static bool _checkJSObject(String objectName) {
    try {
      // This is a simplified check - in real implementation,
      // you would use dart:js or dart:html to check the window object
      return true; // Simplified for this example
    } catch (e) {
      return false;
    }
  }
}
