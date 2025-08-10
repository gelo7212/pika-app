abstract class ProductServiceInterface {
  Future<List<Map<String, dynamic>>> getProducts({
    String? storeId,
    bool grouped = true,
    bool availableForSale = true,
  });
  
  Future<List<Map<String, dynamic>>> getProductsForDisplay();
  
  Future<Map<String, dynamic>?> getProductById(String id);
}
