import 'token_types.dart' as token_types;
import '../models/auth_models.dart';

abstract class AuthInterface {
  Future<void> logout();
  Future<String?> isAccessTokenValid();
  Future<bool> validateAndRefreshToken();
  Future<void> refreshToken();
  Future<token_types.TokenPayload?> decodeToken(String token);
  
  Future<CustomerAuthResponse> customerLogin({
    required String firebaseToken,
    required String provider,
    required String email,
  });
  
  Future<CustomerAuthResponse> customerRegister({
    required String firebaseToken,
    required String provider,
    required String email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    Map<String, dynamic>? address,
  });

  // Helper methods for easier usage
  Future<bool> isLoggedIn() async {
    final token = await isAccessTokenValid();
    return token != null;
  }

  Future<String?> getCurrentUserToken() async {
    return await isAccessTokenValid();
  }
}
