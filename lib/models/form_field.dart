class FormFieldModel {
  final String id;
  final String name;
  final String type;
  final bool required;

  FormFieldModel({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'required': required,
    };
  }

  factory FormFieldModel.fromMap(Map<String, dynamic> map) {
    return FormFieldModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'text',
      required: map['required'] ?? false,
    );
  }

  FormFieldModel copyWith({
    String? id,
    String? name,
    String? type,
    bool? required,
  }) {
    return FormFieldModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
    );
  }
} 