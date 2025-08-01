import 'package:cloud_firestore/cloud_firestore.dart';

class MasterSKU {
  final String id;
  final String name;
  final String description;
  final double? price;
  final String category;
  final String? imageUrl; // Added for image support
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  MasterSKU({
    required this.id,
    required this.name,
    required this.description,
    this.price,
    required this.category,
    this.imageUrl, // Added for image support
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory MasterSKU.fromJson(Map<String, dynamic> json, {String? id}) {
    return MasterSKU(
      id: id ?? json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      category: json['category'] as String,
      imageUrl: json['imageUrl'] as String?, // Added for image support
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl, // Added for image support
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  MasterSKU copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl, // Added for image support
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return MasterSKU(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl, // Added for image support
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
