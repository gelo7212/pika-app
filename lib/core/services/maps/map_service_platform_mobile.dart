// Mobile platform implementation
import 'map_service_interface.dart';
import 'map_service_mobile.dart';

MapServiceInterface createMapService() {
  return MapServiceMobile.instance;
}
