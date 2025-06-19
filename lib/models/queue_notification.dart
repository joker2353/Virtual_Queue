import 'package:json_annotation/json_annotation.dart';

part 'queue_notification.g.dart';

@JsonSerializable()
class QueueNotification {
  final String roomId;
  final String roomName;
  final int currentPosition;
  final int userPosition;
  final String notificationType;
  final String? message;
  
  QueueNotification({
    required this.roomId,
    required this.roomName,
    required this.currentPosition,
    required this.userPosition,
    required this.notificationType,
    this.message,
  });
  
  // For your turn notifications
  factory QueueNotification.yourTurn({
    required String roomId,
    required String roomName,
    required int position,
  }) {
    return QueueNotification(
      roomId: roomId,
      roomName: roomName,
      currentPosition: position,
      userPosition: position,
      notificationType: 'your_turn',
      message: 'It\'s your turn in $roomName!',
    );
  }
  
  // For queue advancement notifications
  factory QueueNotification.queueAdvanced({
    required String roomId,
    required String roomName,
    required int currentPosition,
    required int userPosition,
  }) {
    return QueueNotification(
      roomId: roomId,
      roomName: roomName,
      currentPosition: currentPosition,
      userPosition: userPosition,
      notificationType: 'queue_advanced',
      message: 'The queue in $roomName has advanced. Current position: $currentPosition',
    );
  }
  
  // From JSON factory
  factory QueueNotification.fromJson(Map<String, dynamic> json) => 
      _$QueueNotificationFromJson(json);
  
  // To JSON method
  Map<String, dynamic> toJson() => _$QueueNotificationToJson(this);
  
  // Convert to FCM payload
  Map<String, dynamic> toFcmPayload() {
    return {
      'notification': {
        'title': notificationType == 'your_turn' 
            ? 'It\'s Your Turn!' 
            : 'Queue Update',
        'body': message,
      },
      'data': toJson(),
    };
  }
} 