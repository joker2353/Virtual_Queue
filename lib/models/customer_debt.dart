import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDebt {
  final String id;
  final String roomId;
  final String customerContact;
  final String? customerEmail;
  final double currentDebt;
  final DateTime lastUpdated;
  final List<DebtHistory> debtHistory;
  final List<PaymentHistory> paymentHistory;

  CustomerDebt({
    required this.id,
    required this.roomId,
    required this.customerContact,
    this.customerEmail,
    required this.currentDebt,
    required this.lastUpdated,
    required this.debtHistory,
    required this.paymentHistory,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'customerContact': customerContact,
      'customerEmail': customerEmail,
      'currentDebt': currentDebt,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory CustomerDebt.fromMap(String documentId, Map<String, dynamic> map) {
    return CustomerDebt(
      id: documentId,
      roomId: map['roomId'] as String,
      customerContact: map['customerContact'] as String,
      customerEmail: map['customerEmail'] as String?,
      currentDebt: (map['currentDebt'] as num).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      debtHistory: [], // These will be loaded separately from subcollections
      paymentHistory: [],
    );
  }

  CustomerDebt copyWith({
    String? id,
    String? roomId,
    String? customerContact,
    String? customerEmail,
    double? currentDebt,
    DateTime? lastUpdated,
    List<DebtHistory>? debtHistory,
    List<PaymentHistory>? paymentHistory,
  }) {
    return CustomerDebt(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      customerContact: customerContact ?? this.customerContact,
      customerEmail: customerEmail ?? this.customerEmail,
      currentDebt: currentDebt ?? this.currentDebt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      debtHistory: debtHistory ?? this.debtHistory,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }
}

class DebtHistory {
  final String orderId;
  final double amount;
  final DateTime timestamp;
  final String description;

  DebtHistory({
    required this.orderId,
    required this.amount,
    required this.timestamp,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
    };
  }

  factory DebtHistory.fromMap(Map<String, dynamic> map) {
    return DebtHistory(
      orderId: map['orderId'] as String,
      amount: (map['amount'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      description: map['description'] as String,
    );
  }
}

class PaymentHistory {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String paymentMethod;
  final String? reference;

  PaymentHistory({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.paymentMethod,
    this.reference,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'paymentMethod': paymentMethod,
      'reference': reference,
    };
  }

  factory PaymentHistory.fromMap(String documentId, Map<String, dynamic> map) {
    return PaymentHistory(
      id: documentId,
      amount: (map['amount'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      paymentMethod: map['paymentMethod'] as String,
      reference: map['reference'] as String?,
    );
  }
}
