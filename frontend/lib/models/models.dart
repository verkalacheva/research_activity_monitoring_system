class Researcher {
  final int id;
  final String fullName;
  final String position;

  Researcher({required this.id, required this.fullName, required this.position});

  factory Researcher.fromJson(Map<String, dynamic> json) {
    return Researcher(
      id: json['id'],
      fullName: json['full_name'],
      position: json['position'],
    );
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


