class AchievementResult {
  final int? id;
  final String title;
  final double? points;

  AchievementResult({this.id, required this.title, this.points});

  factory AchievementResult.fromJson(Map<String, dynamic> json) {
    return AchievementResult(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
    };
  }
}

class AchievementStatus {
  final int? id;
  final String title;
  final double? points;

  AchievementStatus({this.id, required this.title, this.points});

  factory AchievementStatus.fromJson(Map<String, dynamic> json) {
    return AchievementStatus(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
    };
  }
}

class AchievementParticipation {
  final int? id;
  final String title;
  final double? points;

  AchievementParticipation({this.id, required this.title, this.points});

  factory AchievementParticipation.fromJson(Map<String, dynamic> json) {
    return AchievementParticipation(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
    };
  }
}
