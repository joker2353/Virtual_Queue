class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String? masterSkuId; // Reference to MasterSKU
  final int? currentStock; // Current inventory level
  final int? minimumStock; // Minimum stock level for alerts
  final String? imageUrl; // Image URL from MasterSKU
  final String roomId; // Room ID where this item belongs
  final List<StockAdjustment> stockHistory; // Stock adjustment history
  final List<PriceAdjustment> priceHistory; // Price adjustment history
  final double? originalPrice; // Original price from master SKU
  final DateTime? priceOverrideExpiry; // When temporary price override expires

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.roomId,
    this.isAvailable = true,
    this.masterSkuId,
    this.currentStock,
    this.minimumStock,
    this.imageUrl,
    this.stockHistory = const [],
    this.priceHistory = const [],
    this.originalPrice,
    this.priceOverrideExpiry,
  });

  factory MenuItem.fromMap(String id, Map<String, dynamic> map) {
    return MenuItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      roomId: map['roomId'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      masterSkuId: map['masterSkuId'],
      currentStock: map['currentStock'],
      minimumStock: map['minimumStock'],
      imageUrl: map['imageUrl'],
      originalPrice: map['originalPrice']?.toDouble(),
      priceOverrideExpiry:
          map['priceOverrideExpiry'] != null
              ? DateTime.parse(map['priceOverrideExpiry'])
              : null,
      stockHistory:
          (map['stockHistory'] as List<dynamic>? ?? [])
              .map((e) => StockAdjustment.fromMap(e as Map<String, dynamic>))
              .toList(),
      priceHistory:
          (map['priceHistory'] as List<dynamic>? ?? [])
              .map((e) => PriceAdjustment.fromMap(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'roomId': roomId,
      'isAvailable': isAvailable,
      'masterSkuId': masterSkuId,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'priceOverrideExpiry': priceOverrideExpiry?.toIso8601String(),
      'stockHistory': stockHistory.map((e) => e.toMap()).toList(),
      'priceHistory': priceHistory.map((e) => e.toMap()).toList(),
    };
  }

  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? roomId,
    bool? isAvailable,
    String? masterSkuId,
    int? currentStock,
    int? minimumStock,
    String? imageUrl,
    List<StockAdjustment>? stockHistory,
    List<PriceAdjustment>? priceHistory,
    double? originalPrice,
    DateTime? priceOverrideExpiry,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      roomId: roomId ?? this.roomId,
      isAvailable: isAvailable ?? this.isAvailable,
      masterSkuId: masterSkuId ?? this.masterSkuId,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      imageUrl: imageUrl ?? this.imageUrl,
      stockHistory: stockHistory ?? this.stockHistory,
      priceHistory: priceHistory ?? this.priceHistory,
      originalPrice: originalPrice ?? this.originalPrice,
      priceOverrideExpiry: priceOverrideExpiry ?? this.priceOverrideExpiry,
    );
  }

  // Helper methods for inventory management
  bool get isLowStock =>
      currentStock != null &&
      minimumStock != null &&
      currentStock! <= minimumStock!;

  bool get isOutOfStock => currentStock != null && currentStock! <= 0;

  bool get hasPriceOverride => originalPrice != null && originalPrice != price;

  bool get isPriceOverrideExpired =>
      priceOverrideExpiry != null &&
      DateTime.now().isAfter(priceOverrideExpiry!);
}

class StockAdjustment {
  final DateTime timestamp;
  final int quantity;
  final String reason;
  final String? userId;

  StockAdjustment({
    required this.timestamp,
    required this.quantity,
    required this.reason,
    this.userId,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      timestamp: DateTime.parse(map['timestamp']),
      quantity: map['quantity'],
      reason: map['reason'],
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'quantity': quantity,
      'reason': reason,
      'userId': userId,
    };
  }
}

class PriceAdjustment {
  final DateTime timestamp;
  final double oldPrice;
  final double newPrice;
  final String reason;
  final String? userId;
  final DateTime? expiryDate;

  PriceAdjustment({
    required this.timestamp,
    required this.oldPrice,
    required this.newPrice,
    required this.reason,
    this.userId,
    this.expiryDate,
  });

  factory PriceAdjustment.fromMap(Map<String, dynamic> map) {
    return PriceAdjustment(
      timestamp: DateTime.parse(map['timestamp']),
      oldPrice: map['oldPrice'].toDouble(),
      newPrice: map['newPrice'].toDouble(),
      reason: map['reason'],
      userId: map['userId'],
      expiryDate:
          map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'reason': reason,
      'userId': userId,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }
}
