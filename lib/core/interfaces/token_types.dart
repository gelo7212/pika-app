import 'dart:convert';

class TokenPair {
  final String accessToken;
  final String userAccessToken;
  final String refreshToken;
  final String clientId;

  TokenPair({
    required this.userAccessToken,
    required this.accessToken,
    required this.refreshToken,
    required this.clientId,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      userAccessToken: json['userAccessToken'] ?? '',
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      clientId: json['clientId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userAccessToken': userAccessToken,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'clientId': clientId,
    };
  }
}

class TokenPayload {
  final String userId;
  final String email;
  final String sub;
  final String accountType;
  final List<String> scopes;
  final DateTime exp;
  final List<dynamic> permissions;
  final String? role;

  TokenPayload({
    required this.userId,
    required this.email,
    required this.sub,
    required this.accountType,
    required this.scopes,
    required this.exp,
    this.permissions = const [],
    this.role,
  });

  bool get isExpired => DateTime.now().isAfter(exp);

  factory TokenPayload.fromJson(Map<String, dynamic> json) {
    return TokenPayload(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      sub: json['sub'] ?? '',
      accountType: json['accountType'] ?? '',
      scopes: List<String>.from(json['scope'] ?? []),
      exp: DateTime.fromMillisecondsSinceEpoch(json['exp'] * 1000),
      permissions: (json['permissions'] as List<dynamic>?) ?? [],
      role: json['role'] as String?,
    );
  }

  static Future<TokenPayload?> decode(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid token format');
      }

      String payload = parts[1];
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          throw Exception('Invalid base64 string');
      }

      final Map<String, dynamic> decodedPayload = json.decode(
        utf8.decode(base64Url.decode(payload)),
      );

      return TokenPayload.fromJson(decodedPayload);
    } catch (e) {
      return null;
    }
  }

  bool hasScope(String scope) => scopes.contains(scope);
  bool hasAnyScope(List<String> requiredScopes) =>
      requiredScopes.any((scope) => scopes.contains(scope));
}

enum TokenType {
  access,
  refresh,
  app;

  bool get isAccess => this == TokenType.access;
  bool get isRefresh => this == TokenType.refresh;
  bool get isApp => this == TokenType.app;
}
