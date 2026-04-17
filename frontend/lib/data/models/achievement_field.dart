class AchievementField {
  final int? id;
  final String title;
  final String fieldType;
  final bool isRequired;
  final List<String> options;
  final bool? destroy;

  AchievementField({
    this.id,
    required this.title,
    required this.fieldType,
    required this.isRequired,
    this.options = const [],
    this.destroy,
  });

  factory AchievementField.fromJson(Map<String, dynamic> json) {
    return AchievementField(
      id: json['id'],
      title: json['title'] ?? '',
      fieldType: json['field_type'] ?? 'string',
      isRequired: json['is_required'] ?? false,
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'field_type': fieldType,
      'is_required': isRequired,
      'options': options,
      if (destroy != null) '_destroy': destroy,
    };
  }

  AchievementField copyWith({
    int? id,
    String? title,
    String? fieldType,
    bool? isRequired,
    List<String>? options,
    bool? destroy,
  }) {
    return AchievementField(
      id: id ?? this.id,
      title: title ?? this.title,
      fieldType: fieldType ?? this.fieldType,
      isRequired: isRequired ?? this.isRequired,
      options: options ?? this.options,
      destroy: destroy ?? this.destroy,
    );
  }
}
