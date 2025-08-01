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
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

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
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isReadyForPickup => status == 'ready_for_pickup';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Check if all items have been checked (either available or not)
  bool get allItemsChecked => items.every((item) => item.isChecked);

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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
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
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
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

  OrderItem({
    required this.name,
    required this.quantity,
    this.notes,
    required this.isAvailable,
    this.isChecked = false,
    this.masterSkuId,
    this.unitPrice,
    this.category,
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
    );
  }

  // Calculate total price for this item
  double get totalPrice => (unitPrice ?? 0.0) * quantity;
}
