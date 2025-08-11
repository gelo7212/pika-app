import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/web_utils.dart';
import '../../../core/utils/firebase_web_auth.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/interfaces/auth_interface.dart';
import '../../../core/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isLoading = false;
  bool _isSigningIn = false; // Add flag to prevent multiple sign-in attempts

  // Configure GoogleSignIn for web with Safari-specific settings
  late final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId:
              '772116536818-sgvhq2nme5qdgv1smn1jdq86si033bd1.apps.googleusercontent.com',
          scopes: [
            'email',
            'profile',
            'openid',
          ],
          // Always force code for web to ensure ID token
          forceCodeForRefreshToken: true,
        )
      : GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    // Prevent multiple simultaneous sign-in attempts
    if (_isSigningIn) {
      debugPrint('Sign-in already in progress, ignoring duplicate request');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSigningIn = true;
    });

    try {
      // Check browser compatibility first
      if (kIsWeb && !WebUtils.isGoogleSignInCompatible) {
        throw 'Your browser may not be fully compatible with Google Sign-In. Please try using Chrome, Firefox, or Edge for the best experience.';
      }

      // Show Safari-specific recommendations
      if (kIsWeb && WebUtils.isSafari) {
        debugPrint('Safari detected: ${WebUtils.authRecommendation}');
      }

      if (kIsWeb) {
        // For web, always use Firebase Auth directly to avoid ID token issues
        debugPrint('Using Firebase direct Google Sign-In for web');
        await _signInWithGoogleFirebaseDirect();
        return;
      }

      // For mobile platforms, use the standard google_sign_in approach
      debugPrint('Using standard Google Sign-In flow for mobile');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        debugPrint('User canceled Google Sign-In');
        return;
      }

      // Obtain the auth details from the request
      GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      debugPrint(
          'Google Sign-In successful: ${googleAuth.accessToken != null}');
      debugPrint('ID Token available: ${googleAuth.idToken != null}');
      debugPrint('Access Token length: ${googleAuth.accessToken?.length ?? 0}');
      debugPrint('ID Token length: ${googleAuth.idToken?.length ?? 0}');

      // Check if we have the required tokens
      if (googleAuth.accessToken == null) {
        throw 'Access token is missing. Please try signing in again.';
      }

      // Create credential with available tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google user credential
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      await _handleSuccessfulGoogleSignIn(user);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(
                seconds: 10), // Longer duration for detailed error messages
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSigningIn = false;
        });
      }
    }
  }

  /// Web-specific Google Sign-In using Firebase Auth directly with popup
  Future<void> _signInWithGoogleFirebaseDirect() async {
    try {
      debugPrint('Attempting Firebase direct Google Sign-In for web');

      // Use the Firebase Web Auth utility for better reliability
      if (FirebaseWebAuth.isAvailable) {
        final UserCredential userCredential =
            await FirebaseWebAuth.signInWithGooglePopup();
        final User? user = userCredential.user;

        if (user != null) {
          debugPrint('Firebase Web Auth successful for user: ${user.email}');
          await _handleSuccessfulGoogleSignIn(user);
          return;
        }
      }

      // Fallback to direct Firebase Auth if utility is not available
      final googleProvider = GoogleAuthProvider();

      // Add required scopes to ensure we get all necessary information
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.addScope('openid');

      // Set custom parameters to improve token handling
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'access_type': 'offline',
        'include_granted_scopes': 'true',
        'response_type':
            'code id_token', // Explicitly request both code and ID token
      });

      debugPrint('Initiating Firebase signInWithPopup...');

      // Sign in with popup
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      final User? user = userCredential.user;

      if (user != null) {
        debugPrint(
            'Firebase direct sign-in successful for user: ${user.email}');
        debugPrint('User UID: ${user.uid}');
        debugPrint('User email verified: ${user.emailVerified}');
        await _handleSuccessfulGoogleSignIn(user);
      } else {
        throw 'No user returned from Firebase auth';
      }
    } catch (e) {
      debugPrint('Firebase direct Google Sign-In error: $e');
      // Provide more specific error messages based on the error type
      String errorMessage = 'Google Sign-In failed';
      if (e.toString().contains('popup')) {
        errorMessage =
            'Sign-in popup was blocked or closed. Please allow popups and try again.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Network error during sign-in. Please check your connection and try again.';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled.';
      }
      throw errorMessage;
    }
  }

  Future<void> _handleSuccessfulGoogleSignIn(User? user) async {
    if (user != null) {
      // Get the Firebase ID token with force refresh to ensure we get a valid token
      final String? idToken = await user.getIdToken(true);

      if (idToken != null) {
        debugPrint(
            'Successfully obtained Firebase ID token for user: ${user.email}');

        // Call backend authentication service
        final authService = serviceLocator<AuthInterface>();

        await authService.customerLogin(
          firebaseToken: idToken,
          provider: 'google',
          email: user.email ?? '',
        );

        if (mounted) {
          // Invalidate auth provider to refresh state
          ref.invalidate(isLoggedInProvider);

          // Check for redirect parameter
          final redirect =
              GoRouterState.of(context).uri.queryParameters['redirect'];

          // Navigate to intended location or home page
          if (redirect != null && redirect.isNotEmpty) {
            context.go(Uri.decodeComponent(redirect));
          } else {
            context.go('/home');
          }
        }
      } else {
        debugPrint(
            'Failed to obtain Firebase ID token for user: ${user.email}');
        throw 'Failed to obtain authentication token. Please try signing in again.';
      }
    } else {
      throw 'No user information received from authentication provider.';
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize Facebook login with updated version
      if (kIsWeb) {
        await FacebookAuth.instance.webAndDesktopInitialize(
          appId: "986376486372517",
          cookie: true,
          xfbml: true,
          version: "v18.0", // Updated version to match SDK
        );
      }

      // Trigger Facebook sign in with explicit permissions
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: kIsWeb
            ? LoginBehavior.dialogOnly // Force dialog login behavior for web
            : LoginBehavior
                .nativeWithFallback, // Native app with fallback for mobile
      );

      debugPrint('Facebook login status: ${result.status}');
      debugPrint('Facebook login message: ${result.message}');

      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;
        debugPrint(
            'Facebook access token available: ${accessToken?.tokenString != null}');

        if (accessToken == null) {
          throw 'Access token is null';
        }

        // Create credential
        final OAuthCredential facebookCredential =
            FacebookAuthProvider.credential(
          accessToken.tokenString,
        );

        // Sign in to Firebase with the Facebook user credential
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(facebookCredential);
        final User? user = userCredential.user;

        if (user == null) {
          throw 'Failed to get user data from Firebase';
        }

        // Get the Firebase ID token
        final String? idToken = await user.getIdToken();
        if (idToken == null) {
          throw 'Failed to get Firebase token';
        }

        debugPrint(
            'Successfully obtained Firebase ID token for Facebook user: ${user.email}');

        // Call backend authentication service
        final authService = serviceLocator<AuthInterface>();

        await authService.customerLogin(
          firebaseToken: idToken,
          provider: 'facebook',
          email: user.email ?? '',
        );

        if (mounted) {
          // Invalidate auth provider to refresh state
          ref.invalidate(isLoggedInProvider);

          // Check for redirect parameter
          final redirect =
              GoRouterState.of(context).uri.queryParameters['redirect'];

          // Navigate to intended location or home page
          if (redirect != null && redirect.isNotEmpty) {
            context.go(Uri.decodeComponent(redirect));
          } else {
            context.go('/home');
          }
        }
      } else if (result.status == LoginStatus.cancelled) {
        // User cancelled the login
        debugPrint('Facebook login cancelled by user');
        return; // Don't show error for user cancellation
      } else {
        // Login failed
        throw 'Facebook login failed: ${result.message ?? 'Unknown error'}';
      }
    } catch (e) {
      debugPrint('Facebook Sign-In error: $e');
      if (mounted) {
        String errorMessage = 'Facebook sign-in failed';

        // Provide more specific error messages
        if (e.toString().contains('Access token is null')) {
          errorMessage =
              'Facebook authentication failed to provide access token. Please try again.';
        } else if (e.toString().contains('Failed to get user data')) {
          errorMessage =
              'Failed to retrieve user information from Facebook. Please try again.';
        } else if (e.toString().contains('Failed to get Firebase token')) {
          errorMessage =
              'Failed to authenticate with Firebase. Please try again.';
        } else if (e.toString().contains('network')) {
          errorMessage =
              'Network error during Facebook sign-in. Please check your connection.';
        } else {
          errorMessage = 'Facebook sign-in failed: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Color palette constants
  static const _colorPalette = {
    'primary': Color(0xFF1B4332), // Deep forest green
    'secondary': Color(0xFF2D6A4F), // Medium forest green
    'accent': Color(0xFF40916C), // Sage green
    'light': Color(0xFFB7E4C7), // Soft mint
    'cream': Color(0xFFF8FDF8), // Off-white with green tint
    'sand': Color(0xFFF5F3F0), // Warm sand
    'charcoal': Color(0xFF2B2B2B), // Dark charcoal
    'peach': Color(0xFFFFF5EE), // Soft peach
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorPalette['cream'],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // App Logo and Title
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _colorPalette['primary'],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _colorPalette['primary']!.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Pika',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _colorPalette['charcoal'],
                        letterSpacing: -1.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Fresh food delivered to your door',
                      style: TextStyle(
                        fontSize: 16,
                        color: _colorPalette['charcoal']!.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Welcome text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _colorPalette['primary'],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue your food journey',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _colorPalette['charcoal']!.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sign-in Container
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _colorPalette['primary']!.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Google Sign-in Button
                          Container(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_isLoading || _isSigningIn)
                                  ? null
                                  : _signInWithGoogle,
                              icon: (_isLoading || _isSigningIn)
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _colorPalette['primary'],
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: _colorPalette['accent'],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.g_mobiledata,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                              label: Text(
                                (_isLoading || _isSigningIn)
                                    ? 'Signing in...'
                                    : 'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _colorPalette['charcoal'],
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _colorPalette['light'],
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: _colorPalette['accent']!
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Facebook Sign-in Button
                          Container(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _signInWithFacebook,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.facebook,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                _isLoading
                                    ? 'Signing in...'
                                    : 'Continue with Facebook',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _colorPalette['secondary'],
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms and Privacy
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _colorPalette['charcoal']!.withOpacity(0.5),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
