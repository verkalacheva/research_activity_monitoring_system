class Researcher {
  final int? id;
  final String name;
  final String surname;
  final String? secondName;
  final String? degreeLevel;
  final int? course;
  final String? subjectArea;
  final String? email;
  final String? telegram;
  final String? isuNumber;
  final String? faculty;
  final String? employmentStatus;
  final bool isLeader;
  final List<Achievement> achievements;

  Researcher({
    this.id,
    required this.name,
    required this.surname,
    this.secondName,
    this.degreeLevel,
    this.course,
    this.subjectArea,
    this.email,
    this.telegram,
    this.isuNumber,
    this.faculty,
    this.employmentStatus,
    this.isLeader = false,
    this.achievements = const [],
  });

  String get fullName => '$surname $name ${secondName ?? ''}'.trim();

  static int compareByFullName(Researcher a, Researcher b) {
    int res = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
    if (res != 0) return res;
    res = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (res != 0) return res;
    return (a.secondName ?? '').toLowerCase().compareTo((b.secondName ?? '').toLowerCase());
  }

  factory Researcher.fromJson(Map<String, dynamic> json) {
    return Researcher(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      secondName: json['second_name'],
      degreeLevel: json['degree_level'],
      course: json['course'],
      subjectArea: json['subject_area'],
      email: json['email'],
      telegram: json['telegram'],
      isuNumber: json['isu_number'],
      faculty: json['faculty'],
      employmentStatus: json['employment_status'],
      isLeader: json['is_leader'] ?? false,
      achievements: (json['achievements'] as List?)
              ?.map((a) => Achievement.fromJson(a))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      'second_name': secondName,
      'degree_level': degreeLevel,
      'course': course,
      'subject_area': subjectArea,
      'email': email,
      'telegram': telegram,
      'isu_number': isuNumber,
      'faculty': faculty,
      'employment_status': employmentStatus,
    };
  }

  Researcher copyWith({
    int? id,
    String? name,
    String? surname,
    String? secondName,
    String? degreeLevel,
    int? course,
    String? subjectArea,
    String? email,
    String? telegram,
    String? isuNumber,
    String? faculty,
    String? employmentStatus,
    bool? isLeader,
    List<Achievement>? achievements,
  }) {
    return Researcher(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      secondName: secondName ?? this.secondName,
      degreeLevel: degreeLevel ?? this.degreeLevel,
      course: course ?? this.course,
      subjectArea: subjectArea ?? this.subjectArea,
      email: email ?? this.email,
      telegram: telegram ?? this.telegram,
      isuNumber: isuNumber ?? this.isuNumber,
      faculty: faculty ?? this.faculty,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      isLeader: isLeader ?? this.isLeader,
      achievements: achievements ?? this.achievements,
    );
  }
}

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

class Achievement {
  final int? id;
  final int achievementTypeId;
  final int achievementStatusId;
  final int achievementResultId;
  final int achievementParticipationId;
  final double? points;
  final DateTime? submissionDate;
  final List<AchievementFieldAnswer> answers;
  final AchievementType? type;
  final AchievementStatus? status;
  final AchievementResult? result;
  final AchievementParticipation? participation;

  Achievement({
    this.id,
    required this.achievementTypeId,
    required this.achievementStatusId,
    required this.achievementResultId,
    required this.achievementParticipationId,
    this.points,
    this.submissionDate,
    this.answers = const [],
    this.type,
    this.status,
    this.result,
    this.participation,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      achievementTypeId: json['achievement_type_id'],
      achievementStatusId: json['achievement_status_id'],
      achievementResultId: json['achievement_result_id'],
      achievementParticipationId: json['achievement_participation_id'],
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
      submissionDate: json['submission_date'] != null ? DateTime.parse(json['submission_date']) : null,
      answers: (json['achievement_field_answers'] as List?)
              ?.map((a) => AchievementFieldAnswer.fromJson(a))
              .toList() ??
          [],
      type: json['achievement_type'] != null ? AchievementType.fromJson(json['achievement_type']) : null,
      status: json['achievement_status'] != null ? AchievementStatus.fromJson(json['achievement_status']) : null,
      result: json['achievement_result'] != null ? AchievementResult.fromJson(json['achievement_result']) : null,
      participation: json['achievement_participation'] != null ? AchievementParticipation.fromJson(json['achievement_participation']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'achievement_type_id': achievementTypeId,
      'achievement_status_id': achievementStatusId,
      'achievement_result_id': achievementResultId,
      'achievement_participation_id': achievementParticipationId,
      if (points != null) 'points': points,
      if (submissionDate != null) 'submission_date': submissionDate!.toIso8601String(),
      'achievement_field_answers_attributes': answers.map((a) => a.toJson()).toList(),
    };
  }
}

class Team {
  final int? id;
  final String title;
  final int? leaderId;
  final Researcher? leader;
  final List<Researcher>? researchers;

  Team({
    this.id,
    required this.title,
    this.leaderId,
    this.leader,
    this.researchers,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      title: json['title'] ?? '',
      leaderId: json['leader_id'],
      leader: json['leader'] != null ? Researcher.fromJson(json['leader']) : null,
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
}

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

class PaginationMetadata {
  final int total;
  final int limit;
  final int offset;

  PaginationMetadata({
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PaginationMetadata.fromJson(Map<String, dynamic> json) {
    return PaginationMetadata(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 20,
      offset: json['offset'] ?? 0,
    );
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMetadata pagination;

  PaginatedResponse({
    required this.items,
    required this.pagination,
  });
}
