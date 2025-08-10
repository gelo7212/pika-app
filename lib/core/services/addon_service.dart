import '../interfaces/addon_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../config/api_config.dart';

class AddonService implements AddonInterface {
  final HttpClientInterface _client;
  
  AddonService({required HttpClientInterface client}) : _client = client;

  @override
  Future<List<Map<String, dynamic>>> getAllAddons() async {
    try {
      final response = await _client.get(
        '${ApiConfig.inventoryUrl}/addson',
        headers: ApiConfig.getDefaultHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          return data.cast<Map<String, dynamic>>();
        }
      }
      
      throw Exception('Failed to fetch addons: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching addons: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getAddonById(String id) async {
    try {
      final response = await _client.get(
        '${ApiConfig.inventoryUrl}/addson/$id',
        headers: ApiConfig.getDefaultHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'] as Map<String, dynamic>;
        }
      }
      
      throw Exception('Failed to fetch addon: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching addon: $e');
    }
  }
}
