class Addon {
  final String addonId;
  final String name;
  final double price;
  final int qty;

  const Addon({
    required this.addonId,
    required this.name,
    required this.price,
    required this.qty,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      addonId: json['addonId'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      qty: json['qty'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addonId': addonId,
      'name': name,
      'price': price,
      'qty': qty,
    };
  }

  Addon copyWith({
    String? addonId,
    String? name,
    double? price,
    int? qty,
  }) {
    return Addon(
      addonId: addonId ?? this.addonId,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Addon &&
        other.addonId == addonId &&
        other.name == name &&
        other.price == price &&
        other.qty == qty;
  }

  @override
  int get hashCode {
    return addonId.hashCode ^ name.hashCode ^ price.hashCode ^ qty.hashCode;
  }

  @override
  String toString() {
    return 'Addon(name: $name, price: $price, qty: $qty)';
  }
}
