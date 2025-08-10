import '../interfaces/auth_interface.dart';
import '../interfaces/token_service_interface.dart';
import '../interfaces/storage_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../interfaces/token_types.dart' as token_types;
import '../models/auth_models.dart';
import '../config/api_config.dart';
import '../exceptions/exceptions.dart';

class AuthService implements AuthInterface {
  final TokenServiceInterface _tokenService;
  final HttpClientInterface _client;

  AuthService({
    required TokenServiceInterface tokenService,
    required SecureStorageInterface storage,
    required HttpClientInterface client,
  })  : _tokenService = tokenService,
        _client = client;

  @override
  Future<token_types.TokenPayload?> decodeToken(String token) async {
    return await token_types.TokenPayload.decode(token);
  }

  @override
  Future<CustomerAuthResponse> customerLogin({
    required String firebaseToken,
    required String provider,
    required String email,
  }) async {
    try {
      final request = CustomerAuthRequest(
        firebaseToken: firebaseToken,
        provider: provider,
        email: email,
      );

      final generatedToken = await _tokenService.generateToken();

      final response = await _client.post(
        '${ApiConfig.authMobileUrl}/mobile/customer/login',
        headers: {
          ...ApiConfig.getDefaultHeaders(),
          'Authorization': 'Bearer $generatedToken',
        },
        body: request.toJson(),
      );

      if (response.statusCode != 200) {
        throw AuthenticationException(
            response.data['message'] ?? 'Customer login failed');
      }

      final data = response.data;
      final tokenData = data['data'] as Map<String, dynamic>;
      final tokens = token_types.TokenPair(
        userAccessToken: tokenData['userAccessToken'] as String,
        accessToken: '',
        refreshToken: tokenData['refreshToken'] as String,
        clientId: tokenData['clientId'] as String? ?? '',
      );

      await _tokenService.saveTokens(tokens);
      return CustomerAuthResponse.fromJson(response.data);
    } catch (e) {
      print('Customer login error: ${e.toString()}');
      throw AuthenticationException('Customer login failed: $e');
    }
  }

  @override
  Future<CustomerAuthResponse> customerRegister({
    required String firebaseToken,
    required String provider,
    required String email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    Map<String, dynamic>? address,
  }) async {
    try {
      final request = CustomerRegisterRequest(
        firebaseToken: firebaseToken,
        provider: provider,
        email: email,
        displayName: displayName,
        photoURL: photoURL,
        phoneNumber: phoneNumber,
        address: address,
      );

      final generatedToken = await _tokenService.generateToken();

      final response = await _client.post(
        '${ApiConfig.authMobileUrl}/mobile/customers',
        headers: {
          ...ApiConfig.getDefaultHeaders(),
          'Authorization': 'Bearer $generatedToken',
        },
        body: request.toJson(),
      );

      if (response.statusCode != 201) {
        throw AuthenticationException(
            response.data['message'] ?? 'Customer registration failed');
      }

      final data = response.data;
      final tokenData = data['data'] as Map<String, dynamic>;
      final tokens = token_types.TokenPair(
        userAccessToken: tokenData['userAccessToken'] as String,
        accessToken: '',
        refreshToken: tokenData['refreshToken'] as String,
        clientId: tokenData['clientId'] as String? ?? '',
      );

      await _tokenService.saveTokens(tokens);
      return CustomerAuthResponse.fromJson(response.data);
    } catch (e) {
      print('Customer registration error: ${e.toString()}');
      throw AuthenticationException('Customer registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _tokenService.clearTokens();
    } catch (e) {
      throw AuthenticationException('Logout failed: $e');
    }
  }

  @override
  Future<String?> isAccessTokenValid() async {
    try {
      final tokens = await _tokenService.getStoredTokens();
      if (tokens == null) return null;

      final isValid = await _tokenService.validateToken(tokens.userAccessToken);
      return isValid ? tokens.userAccessToken : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> validateAndRefreshToken() async {
    try {
      final tokens = await _tokenService.getStoredTokens();
      if (tokens == null) return false;

      final isValid = await _tokenService.validateToken(tokens.userAccessToken);
      if (isValid) return true;

      // Try to refresh the token
      final newTokens = await _tokenService.refreshTokenPair(tokens.refreshToken);
      await _tokenService.saveTokens(newTokens);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      final tokens = await _tokenService.getStoredTokens();
      if (tokens == null) {
        throw AuthenticationException('No tokens found');
      }

      final newTokens = await _tokenService.refreshTokenPair(tokens.refreshToken);
      await _tokenService.saveTokens(newTokens);
    } catch (e) {
      throw AuthenticationException('Token refresh failed: $e');
    }
  }

  // Helper methods implementation
  @override
  Future<bool> isLoggedIn() async {
    final token = await isAccessTokenValid();
    return token != null;
  }

  @override
  Future<String?> getCurrentUserToken() async {
    return await isAccessTokenValid();
  }
}
