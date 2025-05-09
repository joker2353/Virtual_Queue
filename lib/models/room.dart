import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String name;
  final String creatorId;
  final int capacity;
  final int currentPosition;
  final String notice;
  final List<Map<String, dynamic>> formSchema;
  final String status;
  final DateTime createdAt;
  final bool isMember;
  final bool isPending;
  final int userPosition;

  Room({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.capacity,
    required this.currentPosition,
    required this.notice,
    required this.formSchema,
    required this.status,
    required this.createdAt,
    this.isMember = false,
    this.isPending = false,
    this.userPosition = 0,
  });

  factory Room.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    bool isMember = false,
    bool isPending = false,
    int userPosition = 0,
  }) {
    return Room(
      id: id,
      name: data['name'] ?? '',
      creatorId: data['creatorId'] ?? '',
      capacity: data['capacity'] ?? 0,
      currentPosition: data['currentPosition'] ?? 1,
      notice: data['notice'] ?? '',
      formSchema: List<Map<String, dynamic>>.from(data['formSchema'] ?? []),
      status: data['status'] ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMember: isMember,
      isPending: isPending,
      userPosition: userPosition,
    );
  }
}
