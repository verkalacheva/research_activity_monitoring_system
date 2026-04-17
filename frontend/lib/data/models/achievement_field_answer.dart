class AchievementFieldAnswer {
  final int? id;
  final int achievementFieldId;
  final String value;

  AchievementFieldAnswer({
    this.id,
    required this.achievementFieldId,
    required this.value,
  });

  factory AchievementFieldAnswer.fromJson(Map<String, dynamic> json) {
    return AchievementFieldAnswer(
      id: json['id'],
      achievementFieldId: json['achievement_field_id'],
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'achievement_field_id': achievementFieldId,
      'value': value,
    };
  }
}
