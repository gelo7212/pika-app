class HomePageData {
  final List<CategoryItem> categories;
  final List<FeaturedItem> featuredItems;
  final List<SpecialOffer> specialOffers;
  final List<Advertisement> advertisements;

  const HomePageData({
    required this.categories,
    required this.featuredItems,
    required this.specialOffers,
    required this.advertisements,
  });

  factory HomePageData.fromJson(Map<String, dynamic> json) {
    return HomePageData(
      categories: (json['categories'] as List<dynamic>?)
          ?.map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      featuredItems: (json['featured_items'] as List<dynamic>?)
          ?.map((item) => FeaturedItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      specialOffers: (json['special_offers'] as List<dynamic>?)
          ?.map((item) => SpecialOffer.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      advertisements: (json['advertisements'] as List<dynamic>?)
          ?.map((item) => Advertisement.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((item) => item.toJson()).toList(),
      'featured_items': featuredItems.map((item) => item.toJson()).toList(),
      'special_offers': specialOffers.map((item) => item.toJson()).toList(),
      'advertisements': advertisements.map((item) => item.toJson()).toList(),
    };
  }
}

class CategoryItem {
  final String link;
  final String name;
  final String image;
  final String color;

  const CategoryItem({
    required this.link,
    required this.name,
    required this.image,
    required this.color,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      link: json['link'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      color: json['color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'link': link,
      'name': name,
      'image': image,
      'color': color,
    };
  }
}

class FeaturedItem {
  final String name;
  final double price;
  final String id;
  final String image;
  final String category;
  final String description;

  const FeaturedItem({
    required this.name,
    required this.price,
    required this.id,
    required this.image,
    required this.category,
    required this.description,
  });

  factory FeaturedItem.fromJson(Map<String, dynamic> json) {
    return FeaturedItem(
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      id: json['id'] ?? '',
      image: json['image'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'id': id,
      'image': image,
      'category': category,
      'description': description,
    };
  }
}

class SpecialOffer {
  final String type;
  final String id;
  final String name;
  final String details;
  final Map<String, dynamic> properties;

  const SpecialOffer({
    required this.type,
    required this.id,
    required this.name,
    required this.details,
    required this.properties,
  });

  factory SpecialOffer.fromJson(Map<String, dynamic> json) {
    return SpecialOffer(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      details: json['details'] ?? '',
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'name': name,
      'details': details,
      'properties': properties,
    };
  }
}

class Advertisement {
  final String type;
  final String id;
  final String name;
  final String details;
  final Map<String, dynamic> properties;

  const Advertisement({
    required this.type,
    required this.id,
    required this.name,
    required this.details,
    required this.properties,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      details: json['details'] ?? '',
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'name': name,
      'details': details,
      'properties': properties,
    };
  }
}
