import 'dart:convert';
import '../interfaces/token_service_interface.dart';
import '../interfaces/storage_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../interfaces/token_types.dart' as token_types;
import '../config/api_config.dart';
import '../exceptions/exceptions.dart';

class TokenService implements TokenServiceInterface {
  final SecureStorageInterface _storage;
  final HttpClientInterface _client;

  TokenService({
    required SecureStorageInterface storage,
    required HttpClientInterface client,
  })  : _storage = storage,
        _client = client;

  static const String _tokenPairKey = 'token_pair';
  static const String _userNameKey = 'user_name';


  @override
  Future<token_types.TokenPair> refreshTokenPair(String refreshToken) async {
    try {
      final response = await _client.post(
        '${ApiConfig.authMobileUrl}/mobile/refresh-token',
        headers: ApiConfig.getDefaultHeaders(),
        body: {'refreshToken': refreshToken},
      );

      if (response.statusCode != 200) {
        throw AuthenticationException('Token refresh failed');
      }

      return token_types.TokenPair.fromJson(response.data['data']);
    } catch (e) {
      throw AuthenticationException('Token refresh failed: $e');
    }
  }

  @override
  Future<void> saveTokens(token_types.TokenPair tokens) async {
    try {
      final tokenJson = json.encode(tokens.toJson());
      await _storage.write(key: _tokenPairKey, value: tokenJson);
    } catch (e) {
      throw StorageException('Failed to save tokens: $e');
    }
  }

  @override
  Future<token_types.TokenPair?> getStoredTokens() async {
    try {
      final tokenJson = await _storage.read(key: _tokenPairKey);
      if (tokenJson == null) return null;

      final tokenMap = json.decode(tokenJson) as Map<String, dynamic>;
      return token_types.TokenPair.fromJson(tokenMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _tokenPairKey);
      await _storage.delete(key: _userNameKey);
    } catch (e) {
      throw StorageException('Failed to clear tokens: $e');
    }
  }

  @override
  Future<String> generateToken() async {
    try {
      final response = await _client.get(
        '${ApiConfig.authMobileUrl}/mobile/token',
        headers: ApiConfig.getDefaultHeaders(),
      );

      if (response.statusCode != 200) {
        throw AuthenticationException('Token generation failed');
      }

      return response.data['accessToken'] as String;
    } catch (e) {
      throw AuthenticationException('Token generation failed: $e');
    }
  }

  @override
  Future<bool> validateToken(String token) async {
    try {
      final payload = await token_types.TokenPayload.decode(token);
      return payload != null && !payload.isExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _userNameKey);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getTokenPayload(String token) async {
    try {
      final payload = await token_types.TokenPayload.decode(token);
      if (payload == null) return null;

      return {
        'sub': payload.sub,
        'accountType': payload.accountType,
        'scopes': payload.scopes,
        'exp': payload.exp.millisecondsSinceEpoch,
        'permissions': payload.permissions,
        'role': payload.role,
      };
    } catch (e) {
      return null;
    }
  }
}
