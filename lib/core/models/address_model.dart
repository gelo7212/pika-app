class Address {
  final String? id;
  final String name;
  final String address;
  final double longitude;
  final double latitude;
  final String phone;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Address({
    this.id,
    required this.name,
    required this.address,
    required this.longitude,
    required this.latitude,
    required this.phone,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      phone: json['phone'] ?? '',
      isDefault: json['isDefault'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'address': address,
      'longitude': longitude,
      'latitude': latitude,
      'phone': phone,
      'isDefault': isDefault,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Address copyWith({
    String? id,
    String? name,
    String? address,
    double? longitude,
    double? latitude,
    String? phone,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.longitude == longitude &&
        other.latitude == latitude &&
        other.phone == phone &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      address,
      longitude,
      latitude,
      phone,
      isDefault,
    );
  }

  @override
  String toString() {
    return 'Address(id: $id, name: $name, address: $address, phone: $phone)';
  }
}
