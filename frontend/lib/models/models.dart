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
  final int id;
  final String name;

  Team({required this.id, required this.name});

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
    );
  }
}

class AchievementType {
  final int id;
  final String title;

  AchievementType({required this.id, required this.title});

  factory AchievementType.fromJson(Map<String, dynamic> json) {
    return AchievementType(
      id: json['id'],
      title: json['title'],
    );
  }
}
// ... other models can be added similarly


