class DevEmployeeActivityType {
  final int? id;
  final String title;
  final double? points;
  final String? checkKey;

  DevEmployeeActivityType({this.id, required this.title, this.points, this.checkKey});

  factory DevEmployeeActivityType.fromJson(Map<String, dynamic> json) {
    return DevEmployeeActivityType(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? double.tryParse(json['points'].toString()) : null,
      checkKey: json['check_key'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
      'check_key': checkKey,
    };
  }
}

class DevProjectCriterion {
  final int? id;
  final String title;
  final double? points;
  final String? checkKey;

  DevProjectCriterion({this.id, required this.title, this.points, this.checkKey});

  factory DevProjectCriterion.fromJson(Map<String, dynamic> json) {
    return DevProjectCriterion(
      id: json['id'],
      title: json['title'] ?? '',
      points: json['points'] != null ? double.tryParse(json['points'].toString()) : null,
      checkKey: json['check_key'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (points != null) 'points': points,
      'check_key': checkKey,
    };
  }
}
