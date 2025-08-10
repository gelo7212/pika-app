import '../interfaces/product_service_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../config/api_config.dart';

class ProductService implements ProductServiceInterface {
  final HttpClientInterface client;

  ProductService({required this.client});

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? storeId,
    bool grouped = true,
    bool availableForSale = true,
  }) async {
    try {
      final headers = ApiConfig.getDefaultHeaders();
      final Map<String, String> queryParams = {};
      
      if (grouped) queryParams['group'] = 'true';
      if (availableForSale) queryParams['availableForSale'] = 'true';
      
      final queryString = Uri(queryParameters: queryParams).query;
      
      String url;
      if (storeId != null && storeId.isNotEmpty) {
        // Use public store endpoint
        url = '${ApiConfig.inventoryUrl}/product/public/store/$storeId';
      } else {
        // Use public display endpoint when no store
        url = '${ApiConfig.inventoryUrl}/product/public/display';
      }
      
      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }

      final response = await client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final products = data['data'] as List;
          return products.map((product) => product as Map<String, dynamic>).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProductsForDisplay() async {
    try {
      final headers = ApiConfig.getDefaultHeaders();
      final url = '${ApiConfig.inventoryUrl}/product/public/display?group=true';

      final response = await client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final products = data['data'] as List;
          return products.map((product) => product as Map<String, dynamic>).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching display products: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final headers = ApiConfig.getDefaultHeaders();
      final url = '${ApiConfig.inventoryUrl}/product/$id';

      final response = await client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching product by ID: $e');
      return null;
    }
  }
}
