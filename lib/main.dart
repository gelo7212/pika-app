import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/di/service_locator.dart';
import 'core/config/firebase_config.dart';
import 'core/config/maps_config.dart';
import 'core/interfaces/storage_interface.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/map_controller_manager.dart';
import 'core/services/maps/map_service.dart';
import 'core/services/token_validation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and services
  await Future.wait([
    _initializeFirebase(),
    _initializeServiceLocator(),
    _initializeMapServices(),
    _initializeTokenValidation(),
  ]);

  runApp(
    const ProviderScope(
      child: CustomerOrderApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: FirebaseConfig.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}

Future<void> _initializeServiceLocator() async {
  try {
    await setupServiceLocator();
  } catch (e) {
    debugPrint('Service locator initialization error: $e');
    // Try to reset and reinitialize
    if (serviceLocator.isRegistered<SecureStorageInterface>()) {
      await serviceLocator.reset();
      await setupServiceLocator();
    }
  }
}

Future<void> _initializeMapServices() async {
  try {
    // Initialize map cache
    await MapsConfig.initializeMapCache();

    // Initialize MapService (fix for initialization error)
    await MapService.instance.initialize();

    // Initialize map controller manager
    MapControllerManager.instance.initialize();

    debugPrint('Map services initialized successfully');
  } catch (e) {
    debugPrint('Map services initialization error: $e');
  }
}

Future<void> _initializeTokenValidation() async {
  try {
    // Start background token validation
    TokenValidationService.instance.startBackgroundValidation();
    debugPrint('Token validation service initialized successfully');
  } catch (e) {
    debugPrint('Token validation service initialization error: $e');
  }
}

class CustomerOrderApp extends ConsumerWidget {
  const CustomerOrderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(routerProvider);
    GoRouter.optionURLReflectsImperativeAPIs = true;

    return MaterialApp.router(
      title: 'Pika - ESBI Delivery',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
