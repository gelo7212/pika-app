class CustomerAuthRequest {
  final String firebaseToken;
  final String provider;
  final String email;

  CustomerAuthRequest({
    required this.firebaseToken,
    required this.provider,
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'firebaseToken': firebaseToken,
      'provider': provider,
      'email': email,
    };
  }
}

class CustomerAuthResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  CustomerAuthResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CustomerAuthResponse.fromJson(Map<String, dynamic> json) {
    return CustomerAuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}

class CustomerRegisterRequest {
  final String firebaseToken;
  final String provider;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final Map<String, dynamic>? address;

  CustomerRegisterRequest({
    required this.firebaseToken,
    required this.provider,
    required this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.address,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'firebaseToken': firebaseToken,
      'provider': provider,
      'email': email,
    };
    
    if (displayName != null) map['displayName'] = displayName;
    if (photoURL != null) map['photoURL'] = photoURL;
    if (phoneNumber != null) map['phoneNumber'] = phoneNumber;
    if (address != null) map['address'] = address;
    
    return map;
  }
}
