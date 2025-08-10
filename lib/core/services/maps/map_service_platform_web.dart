// Web platform implementation
import 'map_service_interface.dart';
import 'map_service_web.dart';

MapServiceInterface createMapService() {
  return MapServiceWeb.instance;
}
