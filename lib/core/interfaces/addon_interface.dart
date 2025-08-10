abstract class AddonInterface {
  Future<List<Map<String, dynamic>>> getAllAddons();
  Future<Map<String, dynamic>> getAddonById(String id);
}
