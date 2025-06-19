// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueueNotification _$QueueNotificationFromJson(Map<String, dynamic> json) =>
    QueueNotification(
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String,
      currentPosition: (json['currentPosition'] as num).toInt(),
      userPosition: (json['userPosition'] as num).toInt(),
      notificationType: json['notificationType'] as String,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$QueueNotificationToJson(QueueNotification instance) =>
    <String, dynamic>{
      'roomId': instance.roomId,
      'roomName': instance.roomName,
      'currentPosition': instance.currentPosition,
      'userPosition': instance.userPosition,
      'notificationType': instance.notificationType,
      'message': instance.message,
    };
