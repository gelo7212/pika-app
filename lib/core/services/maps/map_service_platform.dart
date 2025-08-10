// Conditional imports for different platforms
export 'map_service_web.dart' if (dart.library.io) 'map_service_mobile.dart';
