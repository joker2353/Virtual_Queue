import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionOrder {
  final String id;
  final String roomId;
  final String userId;
  final String customerName;
  final String customerContact;
  final List<String> prescriptionImageUrls;
  final String? audioInstructionUrl;
  final double totalAmount;
  final String
  status; // 'pending', 'processing', 'ready_for_pickup', 'completed', 'cancelled'
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  PrescriptionOrder({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.customerName,
    required this.customerContact,
    required this.prescriptionImageUrls,
    this.audioInstructionUrl,
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
  bool get hasAudioInstructions =>
      audioInstructionUrl != null && audioInstructionUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'customerName': customerName,
      'customerContact': customerContact,
      'prescriptionImageUrls': prescriptionImageUrls,
      'audioInstructionUrl': audioInstructionUrl,
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
      'orderType': 'prescription', // To distinguish from regular orders
    };
  }

  factory PrescriptionOrder.fromMap(String id, Map<String, dynamic> map) {
    return PrescriptionOrder(
      id: id,
      roomId: map['roomId'] ?? '',
      userId: map['userId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerContact: map['customerContact'] ?? '',
      prescriptionImageUrls: List<String>.from(
        map['prescriptionImageUrls'] ?? [],
      ),
      audioInstructionUrl: map['audioInstructionUrl'],
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  PrescriptionOrder copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? customerName,
    String? customerContact,
    List<String>? prescriptionImageUrls,
    String? audioInstructionUrl,
    double? totalAmount,
    String? status,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PrescriptionOrder(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerContact: customerContact ?? this.customerContact,
      prescriptionImageUrls:
          prescriptionImageUrls ?? this.prescriptionImageUrls,
      audioInstructionUrl: audioInstructionUrl ?? this.audioInstructionUrl,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
