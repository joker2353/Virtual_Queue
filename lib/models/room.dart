import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_field.dart';

class Room {
  final String id;
  final String name;
  final String code;
  final String? qrCodeUrl;
  final String creatorId;
  final int capacity;
  final int currentPosition;
  final int memberCount;
  final String status;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final String notice;
  final List<FormFieldModel> formFields;
  final RoomSettings settings;

  Room({
    required this.id,
    required this.name,
    required this.code,
    this.qrCodeUrl,
    required this.creatorId,
    required this.capacity,
    required this.currentPosition,
    required this.memberCount,
    required this.status,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.notice,
    required this.formFields,
    required this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'qrCodeUrl': qrCodeUrl,
      'creatorId': creatorId,
      'capacity': capacity,
      'currentPosition': currentPosition,
      'memberCount': memberCount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      'notice': notice,
      'formFields': formFields.map((field) => field.toMap()).toList(),
      'settings': settings.toMap(),
    };
  }

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    return Room(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      qrCodeUrl: map['qrCodeUrl'],
      creatorId: map['creatorId'] ?? '',
      capacity: map['capacity'] ?? 0,
      currentPosition: map['currentPosition'] ?? 0,
      memberCount: map['memberCount'] ?? 0,
      status: map['status'] ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedAt: (map['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notice: map['notice'] ?? '',
      formFields: (map['formFields'] as List<dynamic>?)?.map(
            (fieldMap) => FormFieldModel.fromMap(fieldMap as Map<String, dynamic>),
          ).toList() ??
          [],
      settings: RoomSettings.fromMap(
          map['settings'] as Map<String, dynamic>? ?? {}),
    );
  }

  Room copyWith({
    String? id,
    String? name,
    String? code,
    String? qrCodeUrl,
    String? creatorId,
    int? capacity,
    int? currentPosition,
    int? memberCount,
    String? status,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    String? notice,
    List<FormFieldModel>? formFields,
    RoomSettings? settings,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      creatorId: creatorId ?? this.creatorId,
      capacity: capacity ?? this.capacity,
      currentPosition: currentPosition ?? this.currentPosition,
      memberCount: memberCount ?? this.memberCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      notice: notice ?? this.notice,
      formFields: formFields ?? this.formFields,
      settings: settings ?? this.settings,
    );
  }
}

class RoomSettings {
  final bool autoAdvanceQueue;
  final bool allowRejoin;
  final bool notifyNextInLine;

  RoomSettings({
    this.autoAdvanceQueue = false,
    this.allowRejoin = true,
    this.notifyNextInLine = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'autoAdvanceQueue': autoAdvanceQueue,
      'allowRejoin': allowRejoin,
      'notifyNextInLine': notifyNextInLine,
    };
  }

  factory RoomSettings.fromMap(Map<String, dynamic> map) {
    return RoomSettings(
      autoAdvanceQueue: map['autoAdvanceQueue'] ?? false,
      allowRejoin: map['allowRejoin'] ?? true,
      notifyNextInLine: map['notifyNextInLine'] ?? true,
    );
  }

  RoomSettings copyWith({
    bool? autoAdvanceQueue,
    bool? allowRejoin,
    bool? notifyNextInLine,
  }) {
    return RoomSettings(
      autoAdvanceQueue: autoAdvanceQueue ?? this.autoAdvanceQueue,
      allowRejoin: allowRejoin ?? this.allowRejoin,
      notifyNextInLine: notifyNextInLine ?? this.notifyNextInLine,
    );
  }
}
