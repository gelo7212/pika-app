final class Environment {
  static const inventoryUrl = String.fromEnvironment('API_URL_INVENTORY');
  static const userUrl = String.fromEnvironment('API_URL_USER');
  static const authMobileUrl = String.fromEnvironment('API_URL_AUTH_MOBILE');
  static const salesUrl = String.fromEnvironment('API_URL_SALES');
  static const webSocketUrl = String.fromEnvironment('API_URL_WEBSOCKET');
  static const shiftUrl = String.fromEnvironment('API_URL_SHIFT');
  static const clientId = String.fromEnvironment('X_CLIENT_ID');
  static const apiKey = String.fromEnvironment('X_API_KEY');
  static const hashedData = String.fromEnvironment('X_HASHED_DATA');
  static const encryptionKey = String.fromEnvironment('ENCRYPTION_SECRET_KEY');
}
