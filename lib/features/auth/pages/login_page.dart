import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/web_utils.dart';
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

  // Helper method to detect Safari
  bool get _isSafari {
    return WebUtils.isSafari;
  }

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
          // Safari-specific configuration
          signInOption: _isSafari ? SignInOption.standard : SignInOption.standard,
        )
      : GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Safari-specific handling: Don't force sign out as it can cause issues
      if (kIsWeb && !_isSafari) {
        await _googleSignIn.signOut();
        await FirebaseAuth.instance.signOut();
      }

      // For Safari, we need to handle authentication differently
      GoogleSignInAccount? googleUser;
      
      if (kIsWeb && _isSafari) {
        // Safari-specific authentication flow
        try {
          // Try to sign in silently first (if user was previously signed in)
          googleUser = await _googleSignIn.signInSilently();
          if (googleUser == null) {
            // If silent sign-in fails, trigger interactive sign-in
            googleUser = await _googleSignIn.signIn();
          }
        } catch (e) {
          debugPrint('Safari sign-in attempt failed, trying interactive: $e');
          // Fallback to interactive sign-in
          googleUser = await _googleSignIn.signIn();
        }
      } else {
        // Standard flow for other browsers
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      
      debugPrint('Google Sign-In successful for Safari: ${googleAuth.accessToken != null}');
      debugPrint('ID Token available: ${googleAuth.idToken != null}');

      // For Safari, we need both accessToken and idToken
      if (googleAuth.accessToken == null || (kIsWeb && _isSafari && googleAuth.idToken == null)) {
        throw 'Authentication tokens are missing. Please try again.';
      }

      // Create a new credential - Safari works better with both tokens
      final credential = kIsWeb && _isSafari && googleAuth.idToken != null
          ? GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            )
          : GoogleAuthProvider.credential(accessToken: googleAuth.accessToken);

      // Sign in to Firebase with the Google user credential
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Get the Firebase ID token
        final String? idToken = await user.getIdToken();

        if (idToken != null) {
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
            final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
            
            // Navigate to intended location or home page
            if (redirect != null && redirect.isNotEmpty) {
              context.go(Uri.decodeComponent(redirect));
            } else {
              context.go('/home');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For web, wait for Facebook SDK to be ready
      if (kIsWeb) {
        await WebUtils.waitForFacebookSDK();
      }

      // Trigger the sign-in flow
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: kIsWeb 
            ? LoginBehavior.dialogOnly  // Use dialog for web
            : LoginBehavior.nativeWithFallback, // Native app with fallback for mobile
      );

      if (result.status == LoginStatus.success) {
        // Get the access token
        final AccessToken accessToken = result.accessToken!;
        
        // Create a credential for Firebase
        final OAuthCredential facebookCredential = 
            FacebookAuthProvider.credential(accessToken.tokenString);

        // Sign in to Firebase with the Facebook user credential
        final UserCredential userCredential = 
            await FirebaseAuth.instance.signInWithCredential(facebookCredential);
        final User? user = userCredential.user;

        if (user != null) {
          // Get the Firebase ID token
          final String? idToken = await user.getIdToken();

          if (idToken != null) {
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
              final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
              
              // Navigate to intended location or home page
              if (redirect != null && redirect.isNotEmpty) {
                context.go(Uri.decodeComponent(redirect));
              } else {
                context.go('/home');
              }
            }
          }
        }
      } else if (result.status == LoginStatus.cancelled) {
        // User cancelled the login
        debugPrint('Facebook login cancelled by user');
      } else {
        // Login failed
        throw 'Facebook login failed: ${result.message}';
      }
    } catch (e) {
      debugPrint('Facebook Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facebook sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
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
                              color: _colorPalette['charcoal']!.withOpacity(0.6),
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
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: _isLoading 
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
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: _colorPalette['accent'],
                                            borderRadius: BorderRadius.circular(10),
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
                                _isLoading ? 'Signing in...' : 'Continue with Google',
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
                                    color: _colorPalette['accent']!.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Facebook Sign-in Button
                          Container(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _signInWithFacebook,
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
                                _isLoading ? 'Signing in...' : 'Continue with Facebook',
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
