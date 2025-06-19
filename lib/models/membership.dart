import 'package:cloud_firestore/cloud_firestore.dart';

class Membership {
  final String id;
  final String userId;
  final String roomId;
  final String role;
  final String status;
  final int position;
  final Map<String, dynamic> formData;
  final MembershipTimestamps timestamps;
  final DateTime? lastNotified;
  final Map<String, dynamic> metadata;

  Membership({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.role,
    required this.status,
    required this.position,
    required this.formData,
    required this.timestamps,
    this.lastNotified,
    required this.metadata,
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCreator => role == 'creator';
  bool get isMember => role == 'member';

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'roomId': roomId,
      'role': role,
      'status': status,
      'position': position,
      'formData': formData,
      'timestamps': timestamps.toMap(),
      'lastNotified': lastNotified != null ? Timestamp.fromDate(lastNotified!) : null,
      'metadata': metadata,
    };
  }

  factory Membership.fromMap(String id, Map<String, dynamic> map) {
    return Membership(
      id: id,
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      role: map['role'] ?? 'member',
      status: map['status'] ?? 'pending',
      position: map['position'] ?? 0,
      formData: Map<String, dynamic>.from(map['formData'] ?? {}),
      timestamps: MembershipTimestamps.fromMap(
          map['timestamps'] as Map<String, dynamic>? ?? {}),
      lastNotified: (map['lastNotified'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Membership copyWith({
    String? id,
    String? userId,
    String? roomId,
    String? role,
    String? status,
    int? position,
    Map<String, dynamic>? formData,
    MembershipTimestamps? timestamps,
    DateTime? lastNotified,
    Map<String, dynamic>? metadata,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      role: role ?? this.role,
      status: status ?? this.status,
      position: position ?? this.position,
      formData: formData ?? this.formData,
      timestamps: timestamps ?? this.timestamps,
      lastNotified: lastNotified ?? this.lastNotified,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MembershipTimestamps {
  final DateTime requested;
  final DateTime? approved;
  final DateTime? served;
  final DateTime? left;

  MembershipTimestamps({
    required this.requested,
    this.approved,
    this.served,
    this.left,
  });

  Map<String, dynamic> toMap() {
    return {
      'requested': Timestamp.fromDate(requested),
      'approved': approved != null ? Timestamp.fromDate(approved!) : null,
      'served': served != null ? Timestamp.fromDate(served!) : null,
      'left': left != null ? Timestamp.fromDate(left!) : null,
    };
  }

  factory MembershipTimestamps.fromMap(Map<String, dynamic> map) {
    return MembershipTimestamps(
      requested: (map['requested'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approved: (map['approved'] as Timestamp?)?.toDate(),
      served: (map['served'] as Timestamp?)?.toDate(),
      left: (map['left'] as Timestamp?)?.toDate(),
    );
  }

  MembershipTimestamps copyWith({
    DateTime? requested,
    DateTime? approved,
    DateTime? served,
    DateTime? left,
  }) {
    return MembershipTimestamps(
      requested: requested ?? this.requested,
      approved: approved ?? this.approved,
      served: served ?? this.served,
      left: left ?? this.left,
    );
  }
} 