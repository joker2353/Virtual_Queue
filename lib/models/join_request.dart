import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String userId;
  final Map<String, String> formData;
  final DateTime requestedAt;
  final String status;

  JoinRequest({
    required this.userId,
    required this.formData,
    required this.requestedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'formData': formData,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      userId: map['userId'] ?? '',
      formData: Map<String, String>.from(map['formData'] ?? {}),
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }
} 