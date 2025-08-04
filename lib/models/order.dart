import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String roomId;
  final String userId;
  final String customerName;
  final String customerContact;
  final List<OrderItem> items;
  final double totalAmount;
  final String
  status; // 'pending', 'processing', 'ready_for_pickup', 'completed', 'cancelled'
  final String paymentMethod; // 'cash', 'card', etc.
  final String deliveryType; // 'pickup' or 'delivery'
  final String? deliveryAddress; // null for pickup
  final double deliveryFee; // 0.0 for pickup, 50.0 for delivery
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  // NEW FIELDS for better price tracking
  final double subtotalAmount; // Sum of all item prices
  final double totalWithDelivery; // subtotal + delivery fee
  final bool inventoryChecked; // Whether inventory validation completed

  Order({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.customerName,
    required this.customerContact,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.deliveryType,
    this.deliveryAddress,
    required this.deliveryFee,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
    this.subtotalAmount = 0.0,
    this.totalWithDelivery = 0.0,
    this.inventoryChecked = false,
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isReadyForPickup => status == 'ready_for_pickup';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Check if all items have been checked (either available or not)
  bool get allItemsChecked => items.every((item) => item.isChecked);

  // Delivery-related getters
  bool get isDelivery => deliveryType == 'delivery';
  bool get isPickup => deliveryType == 'pickup';
  double get calculatedTotalWithDelivery => totalAmount + deliveryFee;

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'customerName': customerName,
      'customerContact': customerContact,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'deliveryType': deliveryType,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
      'subtotalAmount': subtotalAmount,
      'totalWithDelivery': totalWithDelivery,
      'inventoryChecked': inventoryChecked,
    };
  }

  factory Order.fromMap(String id, Map<String, dynamic> map) {
    return Order(
      id: id,
      roomId: map['roomId'] ?? '',
      userId: map['userId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerContact: map['customerContact'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map(
                (itemMap) => OrderItem.fromMap(itemMap as Map<String, dynamic>),
              )
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      deliveryType: map['deliveryType'] ?? 'pickup',
      deliveryAddress: map['deliveryAddress'] as String?,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
      subtotalAmount: (map['subtotalAmount'] as num?)?.toDouble() ?? 0.0,
      totalWithDelivery: (map['totalWithDelivery'] as num?)?.toDouble() ?? 0.0,
      inventoryChecked: map['inventoryChecked'] as bool? ?? false,
    );
  }

  Order copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? customerName,
    String? customerContact,
    List<OrderItem>? items,
    double? totalAmount,
    String? status,
    String? paymentMethod,
    String? deliveryType,
    String? deliveryAddress,
    double? deliveryFee,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    double? subtotalAmount,
    double? totalWithDelivery,
    bool? inventoryChecked,
  }) {
    return Order(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerContact: customerContact ?? this.customerContact,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      totalWithDelivery: totalWithDelivery ?? this.totalWithDelivery,
      inventoryChecked: inventoryChecked ?? this.inventoryChecked,
    );
  }
}

class OrderItem {
  final String name;
  final int quantity; // Changed from String to int
  final String? notes;
  final bool isAvailable;
  final bool isChecked;
  final String? masterSkuId; // Reference to MasterSKU
  final double? unitPrice; // Price per unit at time of order
  final String? category; // Category from MasterSKU
  // NEW FIELDS for inventory-based ordering
  final String? menuItemId; // Reference to specific menu item
  final double totalPrice; // Calculated price for this item
  final bool inventoryValidated; // Whether inventory check passed
  final int? availableStock; // Available stock at time of order

  OrderItem({
    required this.name,
    required this.quantity,
    this.notes,
    required this.isAvailable,
    this.isChecked = false,
    this.masterSkuId,
    this.unitPrice,
    this.category,
    this.menuItemId,
    this.totalPrice = 0.0,
    this.inventoryValidated = false,
    this.availableStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'notes': notes,
      'isAvailable': isAvailable,
      'isChecked': isChecked,
      'masterSkuId': masterSkuId,
      'unitPrice': unitPrice,
      'category': category,
      'menuItemId': menuItemId,
      'totalPrice': totalPrice,
      'inventoryValidated': inventoryValidated,
      'availableStock': availableStock,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawQuantity = map['quantity'];
    final int quantity =
        rawQuantity is String
            ? int.tryParse(rawQuantity) ?? 1
            : (rawQuantity as int? ?? 1);

    return OrderItem(
      name: map['name'] as String,
      quantity: quantity,
      notes: map['notes'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isChecked: map['isChecked'] as bool? ?? false,
      masterSkuId: map['masterSkuId'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
      category: map['category'] as String?,
      menuItemId: map['menuItemId'] as String?,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      inventoryValidated: map['inventoryValidated'] as bool? ?? false,
      availableStock: map['availableStock'] as int?,
    );
  }

  OrderItem copyWith({
    String? name,
    int? quantity,
    String? notes,
    bool? isAvailable,
    bool? isChecked,
    String? masterSkuId,
    double? unitPrice,
    String? category,
    String? menuItemId,
    double? totalPrice,
    bool? inventoryValidated,
    int? availableStock,
  }) {
    return OrderItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      isAvailable: isAvailable ?? this.isAvailable,
      isChecked: isChecked ?? this.isChecked,
      masterSkuId: masterSkuId ?? this.masterSkuId,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
      menuItemId: menuItemId ?? this.menuItemId,
      totalPrice: totalPrice ?? this.totalPrice,
      inventoryValidated: inventoryValidated ?? this.inventoryValidated,
      availableStock: availableStock ?? this.availableStock,
    );
  }

  // Calculate total price for this item (fallback if totalPrice field is not set)
  double get calculatedTotalPrice => (unitPrice ?? 0.0) * quantity;
}
