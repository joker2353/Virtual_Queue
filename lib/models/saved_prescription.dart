import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPrescription {
  final String id;
  final String userId;
  final String name;
  final List<String> imageUrls;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime? lastUsed;
  final int usageCount;
  final Map<String, dynamic>? metadata;

  SavedPrescription({
    required this.id,
    required this.userId,
    required this.name,
    required this.imageUrls,
    this.audioUrl,
    required this.createdAt,
    this.lastUsed,
    this.usageCount = 0,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'imageUrls': imageUrls,
      'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'usageCount': usageCount,
      'metadata': metadata,
    };
  }

  factory SavedPrescription.fromMap(String id, Map<String, dynamic> map) {
    return SavedPrescription(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      audioUrl: map['audioUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUsed: (map['lastUsed'] as Timestamp?)?.toDate(),
      usageCount: map['usageCount'] ?? 0,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  SavedPrescription copyWith({
    String? id,
    String? userId,
    String? name,
    List<String>? imageUrls,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? usageCount,
    Map<String, dynamic>? metadata,
  }) {
    return SavedPrescription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      imageUrls: imageUrls ?? this.imageUrls,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  int get imageCount => imageUrls.length;
}
