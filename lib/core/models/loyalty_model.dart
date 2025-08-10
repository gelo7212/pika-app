class LoyaltyCard {
  final String id;
  final String cardNumber;
  final String userId;
  final double currentPoints;
  final double expiredPoints;
  final double soonToExpirePoints;
  final DateTime? expiryDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? encryptId; // Optional encrypted ID
  final List<PointsTransaction>? transactions; // Add transactions to the card

  const LoyaltyCard({
    required this.id,
    required this.cardNumber,
    required this.userId,
    required this.currentPoints,
    required this.expiredPoints,
    required this.soonToExpirePoints,
    this.expiryDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.transactions,
    this.encryptId,
  });

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) {
    // Parse transactions if available
    final transactionsList = json['transactions'] as List? ?? [];
    final transactions = transactionsList
        .map((t) => PointsTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    // Calculate expired and soon-to-expire points from transactions
    double expiredPoints = 0.0;
    double soonToExpirePoints = 0.0;

    for (final transaction in transactions) {
      if (transaction.isEarned) {
        if (transaction.arePointsExpired) {
          expiredPoints += transaction.amount;
        } else if (transaction.willExpireSoon) {
          soonToExpirePoints += transaction.amount;
        }
      }
    }

    return LoyaltyCard(
      id: json['_id'] as String? ?? json['id'] as String,
      cardNumber:
          json['cardNumber'] as String? ?? json['encryptId'] as String? ?? '',
      userId: json['customerId'] as String? ?? json['userId'] as String? ?? '',
      currentPoints: (json['validPoints'] as num?)?.toDouble() ??
          (json['totalPoints'] as num?)?.toDouble() ??
          (json['currentPoints'] as num?)?.toDouble() ??
          0.0,
      expiredPoints:
          (json['expiredPoints'] as num?)?.toDouble() ?? expiredPoints,
      soonToExpirePoints: (json['soonToExpirePoints'] as num?)?.toDouble() ??
          soonToExpirePoints,
      expiryDate: json['validUntil'] != null
          ? DateTime.parse(json['validUntil'] as String)
          : json['expiryDate'] != null
              ? DateTime.parse(json['expiryDate'] as String)
              : null,
      status: json['isActive'] == true
          ? 'active'
          : json['status'] as String? ?? 'inactive',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      encryptId: json['encryptId'] as String?,
      transactions: transactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardNumber': cardNumber,
      'userId': userId,
      'currentPoints': currentPoints,
      'expiredPoints': expiredPoints,
      'soonToExpirePoints': soonToExpirePoints,
      'expiryDate': expiryDate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'encryptId': encryptId,
      'transactions': transactions?.map((t) => t.toJson()).toList(),
    };
  }

  double get availablePoints => currentPoints;

  // Get transactions history (earned, redeemed, etc.)
  List<PointsTransaction> get earnedTransactions =>
      transactions?.where((t) => t.isEarned).toList() ?? [];

  List<PointsTransaction> get redeemedTransactions =>
      transactions?.where((t) => t.isRedeemed).toList() ?? [];

  List<PointsTransaction> get expiredTransactions =>
      transactions?.where((t) => t.arePointsExpired && t.isEarned).toList() ??
      [];

  List<PointsTransaction> get soonToExpireTransactions =>
      transactions?.where((t) => t.willExpireSoon && t.isEarned).toList() ?? [];

  // Get summary statistics
  double get totalEarnedPoints =>
      earnedTransactions.fold(0.0, (sum, t) => sum + t.amount);

  double get totalRedeemedPoints =>
      redeemedTransactions.fold(0.0, (sum, t) => sum + t.amount);

  // Helper to get customer display information
  String get displayName {
    // Try to extract customer name from transactions metadata or use card number
    return cardNumber.isNotEmpty
        ? 'Card ${cardNumber.substring(0, 8)}...'
        : 'Loyalty Card';
  }
}

class PointsTransaction {
  final String id;
  final String cardId;
  final String type; // 'earn', 'redeem', 'adjustment', 'expire'
  final double amount;
  final String? description;
  final String? orderId;
  final DateTime transactionDate;
  final Map<String, dynamic>? metadata;

  const PointsTransaction({
    required this.id,
    required this.cardId,
    required this.type,
    required this.amount,
    this.description,
    this.orderId,
    required this.transactionDate,
    this.metadata,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    // Generate a unique ID if not provided (for embedded transactions)
    final id = json['_id'] as String? ??
        json['id'] as String? ??
        '${json['orderId'] ?? ''}_${json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch}';

    // Convert type to lowercase for consistency
    final typeValue = json['type'] as String? ?? 'earn';
    final normalizedType = typeValue.toLowerCase();

    return PointsTransaction(
      id: id,
      cardId: json['cardId'] as String? ?? '',
      type: normalizedType,
      amount: (json['points'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0.0,
      description: json['description'] as String?,
      orderId: json['orderId'] as String?,
      transactionDate: DateTime.parse(
          json['createdAt'] as String? ?? json['transactionDate'] as String),
      metadata: json['expiryDate'] != null
          ? {'expiryDate': json['expiryDate']}
          : json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardId': cardId,
      'type': type,
      'amount': amount,
      'description': description,
      'orderId': orderId,
      'transactionDate': transactionDate.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isEarned => type == 'earn';
  bool get isRedeemed => type == 'redeem';
  bool get isAdjustment => type == 'adjustment';
  bool get isExpired => type == 'expire';

  // Get expiry date from metadata
  DateTime? get expiryDate {
    if (metadata?['expiryDate'] != null) {
      return DateTime.parse(metadata!['expiryDate'] as String);
    }
    return null;
  }

  // Check if points are expired
  bool get arePointsExpired {
    final expiry = expiryDate;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  // Check if points will expire soon (within 30 days)
  bool get willExpireSoon {
    final expiry = expiryDate;
    if (expiry == null) return false;
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    return expiry.isBefore(thirtyDaysFromNow) && expiry.isAfter(now);
  }
}

class RedeemableProduct {
  final String id;
  final String name;
  final String description;
  final int price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final Map<String, dynamic>? metadata;
  final double pts;

  const RedeemableProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    required this.isAvailable,
    this.metadata,
    required this.pts,
  });

  factory RedeemableProduct.fromJson(Map<String, dynamic> json) {
    return RedeemableProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      category: json['category'] as String? ?? 'general',
      isAvailable: json['isAvailable'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
      pts: (json['pts'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
      'metadata': metadata,
      'pts': pts,
    };
  }
}

class LoyaltyCardHistory {
  final LoyaltyCard card;
  final List<PointsTransaction> transactions;

  const LoyaltyCardHistory({
    required this.card,
    required this.transactions,
  });

  factory LoyaltyCardHistory.fromJson(Map<String, dynamic> json) {
    final card = LoyaltyCard.fromJson(json['card'] as Map<String, dynamic>);
    final transactionsList = json['transactions'] as List? ?? [];
    final transactions = transactionsList
        .map((t) => PointsTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    return LoyaltyCardHistory(
      card: card,
      transactions: transactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card': card.toJson(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }
}

class UserLoyaltyData {
  final List<LoyaltyCard> cards;
  final double totalAvailablePoints;
  final double totalExpiredPoints;
  final double totalSoonToExpirePoints;

  const UserLoyaltyData({
    required this.cards,
    required this.totalAvailablePoints,
    required this.totalExpiredPoints,
    required this.totalSoonToExpirePoints,
  });

  factory UserLoyaltyData.fromJson(Map<String, dynamic> json) {
    final cardsList = json['cards'] as List? ?? [];
    final cards = cardsList
        .map((c) => LoyaltyCard.fromJson(c as Map<String, dynamic>))
        .toList();

    return UserLoyaltyData(
      cards: cards,
      totalAvailablePoints:
          (json['totalAvailablePoints'] as num?)?.toDouble() ?? 0.0,
      totalExpiredPoints:
          (json['totalExpiredPoints'] as num?)?.toDouble() ?? 0.0,
      totalSoonToExpirePoints:
          (json['totalSoonToExpirePoints'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cards': cards.map((c) => c.toJson()).toList(),
      'totalAvailablePoints': totalAvailablePoints,
      'totalExpiredPoints': totalExpiredPoints,
      'totalSoonToExpirePoints': totalSoonToExpirePoints,
    };
  }

  // Aggregate data from individual cards
  factory UserLoyaltyData.fromCards(List<LoyaltyCard> cards) {
    double totalAvailable = 0.0;
    double totalExpired = 0.0;
    double totalSoonToExpire = 0.0;

    for (final card in cards) {
      totalAvailable += card.currentPoints;
      totalExpired += card.expiredPoints;
      totalSoonToExpire += card.soonToExpirePoints;
    }

    return UserLoyaltyData(
      cards: cards,
      totalAvailablePoints: totalAvailable,
      totalExpiredPoints: totalExpired,
      totalSoonToExpirePoints: totalSoonToExpire,
    );
  }
}
