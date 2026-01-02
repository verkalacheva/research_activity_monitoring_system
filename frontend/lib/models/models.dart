class Researcher {
  final int? id;
  final String name;
  final String surname;
  final String? secondName;
  final String? degreeLevel;
  final int? course;
  final String? subjectArea;

  Researcher({
    this.id,
    required this.name,
    required this.surname,
    this.secondName,
    this.degreeLevel,
    this.course,
    this.subjectArea,
  });

  String get fullName => '$surname $name ${secondName ?? ''}'.trim();

  factory Researcher.fromJson(Map<String, dynamic> json) {
    return Researcher(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      secondName: json['second_name'],
      degreeLevel: json['degree_level'],
      course: json['course'],
      subjectArea: json['subject_area'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'surname': surname,
      'second_name': secondName,
      'degree_level': degreeLevel,
      'course': course,
      'subject_area': subjectArea,
    };
  }
}

class Team {
  final int? id;
  final String title;
  final int? leaderId;
  final List<Researcher>? researchers;

  Team({
    this.id,
    required this.title,
    this.leaderId,
    this.researchers,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      title: json['title'] ?? '',
      leaderId: json['leader_id'],
      researchers: json['researchers'] != null
          ? (json['researchers'] as List)
              .map((r) => Researcher.fromJson(r))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'leader_id': leaderId,
      if (researchers != null)
        'researcher_ids': researchers!.map((r) => r.id).toList(),
    };
  }
}

class AchievementType {
  final int? id;
  final String title;
  final double? points;

  AchievementType({this.id, required this.title, this.points});

  factory AchievementType.fromJson(Map<String, dynamic> json) {
    return AchievementType(
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

// ... other models can be added similarly


