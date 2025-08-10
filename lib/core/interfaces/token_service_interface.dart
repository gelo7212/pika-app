import 'token_types.dart' as token_types;

abstract class TokenServiceInterface {
  Future<token_types.TokenPair> refreshTokenPair(String refreshToken);
  Future<void> saveTokens(token_types.TokenPair tokens);
  Future<token_types.TokenPair?> getStoredTokens();
  Future<void> clearTokens();
  Future<String> generateToken();
  Future<bool> validateToken(String token);
  Future<String?> getUserName();
  Future<Map<String, dynamic>?> getTokenPayload(String token);
}
