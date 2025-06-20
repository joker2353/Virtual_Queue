import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoom {
  final String roomId;
  final String name;
  final String type; // 'created' or 'joined'
  final String status; // 'pending' or 'active'
  final int position;
  final int currentPosition;
  final int memberCount;
  final DateTime joinedAt;

  UserRoom({
    required this.roomId,
    required this.name,
    required this.type,
    required this.status,
    required this.position,
    required this.currentPosition,
    required this.memberCount,
    required this.joinedAt,
  });

  bool get isCreated => type == 'created';
  bool get isJoined => type == 'joined';
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';

  // Calculate how many people are ahead in the queue
  int get waitingCount =>
      isPending
          ? 0
          : position > currentPosition
          ? position - currentPosition
          : 0;

  // Fix: Check if position is greater than 0 (not creator) and equals current position
  bool get isCurrentlyServed =>
      position > 0 && position == currentPosition && isActive;

  // Calculate wait time estimate (5 minutes per person)
  String get estimatedWaitTime {
    if (isPending) return 'Waiting for approval';
    if (isCurrentlyServed) return 'It\'s your turn!';
    if (currentPosition == 0) return 'Queue not started';

    final waitMins = waitingCount * 5;
    if (waitMins < 60) {
      return '$waitMins minutes';
    } else {
      final hours = waitMins ~/ 60;
      final mins = waitMins % 60;
      return '$hours hour${hours > 1 ? 's' : ''}${mins > 0 ? ', $mins min' : ''}';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'name': name,
      'type': type,
      'status': status,
      'position': position,
      'currentPosition': currentPosition,
      'memberCount': memberCount,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory UserRoom.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return UserRoom(
      roomId: map['roomId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'joined',
      status: map['status'] ?? 'pending',
      position: map['position']?.toInt() ?? 0,
      currentPosition: map['currentPosition']?.toInt() ?? 0,
      memberCount: map['memberCount']?.toInt() ?? 0,
      joinedAt: parseTimestamp(map['joinedAt']),
    );
  }

  UserRoom copyWith({
    String? roomId,
    String? name,
    String? type,
    String? status,
    int? position,
    int? currentPosition,
    int? memberCount,
    DateTime? joinedAt,
  }) {
    return UserRoom(
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      position: position ?? this.position,
      currentPosition: currentPosition ?? this.currentPosition,
      memberCount: memberCount ?? this.memberCount,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
