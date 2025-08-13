import 'package:equatable/equatable.dart';

enum DiscountType { percentage, fixed }
enum DiscountFor { deliveryApp, pointOfSale }

class ApplicableOnlyIf {
  final List<String> productIds;
  final int? requiredProductCount;

  ApplicableOnlyIf({
    required this.productIds,
    this.requiredProductCount,
  });

  factory ApplicableOnlyIf.fromJson(Map<String, dynamic> json) {
    return ApplicableOnlyIf(
      productIds: List<String>.from(json['productIds'] ?? []),
      requiredProductCount: json['requiredProductCount'],
    );
  }

  Map<String, dynamic> toJson() => {
        'productIds': productIds,
        if (requiredProductCount != null)
          'requiredProductCount': requiredProductCount,
      };
}

class DiscountModel extends Equatable {
  // final 
  final String code;
  final String name;
  final DiscountType type;
  final double value;
  final int? maxUses;
  final int usedCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? description;
  final List<String>? productIds;
  final List<String>? categoryIds;
  final double? minPurchaseAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool applyToAllProducts;
  final String storeId;
  final bool? itemLevel;
  final List<ApplicableOnlyIf>? applicableOnlyIf;
  final bool isBundledDiscount;
  final DiscountFor discountFor;
  final bool firstTimeDiscount;
  final int perAccountUsageLimit;
  final String id;

  const DiscountModel({
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    this.maxUses,
    required this.usedCount,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.description,
    this.productIds,
    this.categoryIds,
    this.minPurchaseAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.applyToAllProducts,
    required this.storeId,
    this.itemLevel,
    this.applicableOnlyIf,
    required this.isBundledDiscount,
    required this.discountFor,
    required this.firstTimeDiscount,
    required this.perAccountUsageLimit,
    required this.id,
  });

  factory DiscountModel.fromJson(Map<String, dynamic> json) {
    return DiscountModel(
      code: json['code'],
      name: json['name'],
      type: DiscountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      maxUses: json['maxUses'],
      usedCount: json['usedCount'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'],
      description: json['description'],
      productIds: json['productIds'] != null ? List<String>.from(json['productIds']) : null,
      categoryIds: json['categoryIds'] != null ? List<String>.from(json['categoryIds']) : null,
      minPurchaseAmount: json['minPurchaseAmount'] != null ? (json['minPurchaseAmount'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      applyToAllProducts: json['applyToAllProducts'],
      storeId: json['storeId'],
      itemLevel: json['itemLevel'],
      applicableOnlyIf: json['applicableOnlyIf'] != null
          ? (json['applicableOnlyIf'] as List)
              .map((e) => ApplicableOnlyIf.fromJson(e))
              .toList()
          : null,
      isBundledDiscount: json['isBundledDiscount'],
      discountFor: DiscountFor.values.firstWhere(
        (e) => e.name == json['discountFor'],
        orElse: () => DiscountFor.deliveryApp,
      ),
      firstTimeDiscount: json['firstTimeDiscount'],
      perAccountUsageLimit: json['perAccountUsageLimit'],
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'type': type.name,
        'value': value,
        if (maxUses != null) 'maxUses': maxUses,
        'usedCount': usedCount,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'isActive': isActive,
        if (description != null) 'description': description,
        if (productIds != null) 'productIds': productIds,
        if (categoryIds != null) 'categoryIds': categoryIds,
        if (minPurchaseAmount != null) 'minPurchaseAmount': minPurchaseAmount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'applyToAllProducts': applyToAllProducts,
        'storeId': storeId,
        if (itemLevel != null) 'itemLevel': itemLevel,
        if (applicableOnlyIf != null)
          'applicableOnlyIf': applicableOnlyIf!.map((e) => e.toJson()).toList(),
        'isBundledDiscount': isBundledDiscount,
        'discountFor': discountFor.name,
        'firstTimeDiscount': firstTimeDiscount,
        'perAccountUsageLimit': perAccountUsageLimit,
        '_id': id,
      };

  @override
  List<Object?> get props => [
        code,
        name,
        type,
        value,
        maxUses,
        usedCount,
        startDate,
        endDate,
        isActive,
        description,
        productIds,
        categoryIds,
        minPurchaseAmount,
        createdAt,
        updatedAt,
        applyToAllProducts,
        storeId,
        itemLevel,
        applicableOnlyIf,
        isBundledDiscount,
        discountFor,
        firstTimeDiscount,
        perAccountUsageLimit,
      ];
}