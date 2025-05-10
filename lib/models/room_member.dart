import 'package:cloud_firestore/cloud_firestore.dart';

class RoomMember {
  final String userId;
  final int position;
  final DateTime joinedAt;

  RoomMember({
    required this.userId,
    required this.position,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'position': position,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    return RoomMember(
      userId: map['userId'] ?? '',
      position: map['position'] ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
} 