import 'achievement_field.dart';

class AchievementType {
  final int? id;
  final String title;
  final double? points;
  final String? iconName;
  final List<AchievementField> fields;

  AchievementType({
    this.id,
    required this.title,
    this.points,
    this.iconName,
    this.fields = const [],
  });

  factory AchievementType.fromJson(Map<String, dynamic> json) {
    return AchievementType(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
      iconName: json['icon_name'],
      fields: (json['achievement_fields'] as List?)
              ?.map((f) => AchievementField.fromJson(f))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
      if (iconName != null) 'icon_name': iconName,
      'achievement_fields_attributes': fields.map((f) => f.toJson()).toList(),
    };
  }
}
