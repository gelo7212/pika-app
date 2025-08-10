class UserProfileModel {
  final String id;
  final String name;
  final String email;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}