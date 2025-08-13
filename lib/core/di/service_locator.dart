import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces/auth_interface.dart';
import '../interfaces/storage_interface.dart';
import '../interfaces/token_service_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../interfaces/product_service_interface.dart';
import '../interfaces/addon_interface.dart';
import '../interfaces/websocket_service_interface.dart';
import '../interfaces/discount_interface.dart';
import '../services/auth_service.dart';
import '../services/secure_storage.dart';
import '../services/token_service.dart';
import '../services/dio_client.dart';
import '../services/address_service.dart';
import '../services/store_service.dart';
import '../services/product_service.dart';
import '../services/addon_service.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';
import '../services/socket_io_service.dart';
import '../services/discount_service.dart';
import '../config/api_config.dart';
import '../../environment.dart';

final serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Check if already initialized to prevent duplicate registration
  if (serviceLocator.isRegistered<SecureStorageInterface>()) {
    return;
  }

  // Core services
  serviceLocator.registerSingleton<SecureStorageInterface>(SecureStorage());

  // HTTP Client registration
  serviceLocator.registerLazySingleton<HttpClientInterface>(
    () => DioClient(),
  );

  // Token and Auth services
  serviceLocator.registerLazySingleton<TokenServiceInterface>(
    () => TokenService(
      storage: serviceLocator<SecureStorageInterface>(),
      client: serviceLocator<HttpClientInterface>(),
    ),
  );

  serviceLocator.registerLazySingleton<AuthInterface>(
    () => AuthService(
      tokenService: serviceLocator<TokenServiceInterface>(),
      storage: serviceLocator<SecureStorageInterface>(),
      client: serviceLocator<HttpClientInterface>(),
    ),
  );

  // Address Service
  serviceLocator.registerLazySingleton<AddressService>(
    () => AddressService(
      dio: (serviceLocator<HttpClientInterface>() as DioClient).dio,
      baseUrl: Environment.userUrl.isNotEmpty
          ? Environment.userUrl
          : 'https://api.dev.esbi-app.name',
    ),
  );

  // Store Service
  serviceLocator.registerLazySingleton<StoreService>(
    () => StoreService(
      dio: (serviceLocator<HttpClientInterface>() as DioClient).dio,
      baseUrl: Environment.userUrl.isNotEmpty
          ? Environment.userUrl
          : 'https://api.dev.esbi-app.name',
    ),
  );

  // Product Service
  serviceLocator.registerLazySingleton<ProductService>(
    () => ProductService(
      client: serviceLocator<HttpClientInterface>(),
    ),
  );

  // Addon Service
  serviceLocator.registerLazySingleton<AddonInterface>(
    () => AddonService(
      client: serviceLocator<HttpClientInterface>(),
    ),
  );

  // Order Service
  serviceLocator.registerLazySingleton<OrderService>(
    () => OrderService(
      dio: (serviceLocator<HttpClientInterface>() as DioClient).dio,
      baseUrl: Environment.salesUrl.isNotEmpty
          ? Environment.salesUrl
          : 'https://api.dev.esbi-app.name',
    ),
  );

  // Delivery Service
  serviceLocator.registerLazySingleton<DeliveryService>(
    () => DeliveryService(),
  );

  // Discount Service
  serviceLocator.registerLazySingleton<DiscountServiceInterface>(
    () => DiscountService(
      client: serviceLocator<HttpClientInterface>(),
      baseUrl: ApiConfig.inventoryUrl,
    ),
  );

  // WebSocket Service
  serviceLocator.registerLazySingleton<WebSocketServiceInterface>(
    () => SocketIOService(),
  );

  // Shared Preferences for app settings
  final prefs = await SharedPreferences.getInstance();
  serviceLocator.registerSingleton<SharedPreferences>(prefs);
}
