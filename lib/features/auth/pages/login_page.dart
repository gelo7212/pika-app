import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/interfaces/auth_interface.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isLoading = false;

  // Configure GoogleSignIn for web
  late final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId:
              '772116536818-sgvhq2nme5qdgv1smn1jdq86si033bd1.apps.googleusercontent.com',
          scopes: [
            'email',
            'profile',
            'openid',
          ],
        )
      : GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Force sign out to ensure fresh authentication on web
      if (kIsWeb) {
        await _googleSignIn.signOut();
        await FirebaseAuth.instance.signOut();
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

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
      print('Google Sign-In successful: ${googleAuth.accessToken}');
      print('Google Sign-In ID Token: ${googleAuth}');

      // Check if we have the required tokens
      if (googleAuth.accessToken == null) {
        throw 'Authentication tokens are missing. Please try again.';
      }

      // Create a new credential
      final credential =
          GoogleAuthProvider.credential(accessToken: googleAuth.accessToken);

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

            // Navigate to home page using GoRouter
            context.go('/home');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pika - ESBI Delivery',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 48),
              Text(
                'Sign in to start ordering',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 32),
              GoogleSignInButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
