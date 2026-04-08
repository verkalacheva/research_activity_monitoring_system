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
  final String? orcidId;
  final String? openalexId;
  final String? github;
  final double? totalDevPoints;
  final bool isLeader;
  final List<Achievement> achievements;
  final List<ResearcherDevActivity> devActivities;
  final List<ResearcherActivityDetail> activityDetails;
  // teamId -> project_sum (dev_criteria_sum + dev_activities_sum)
  final Map<int, double> devTeamMultipliers;

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
    this.orcidId,
    this.openalexId,
    this.github,
    this.totalDevPoints,
    this.isLeader = false,
    this.achievements = const [],
    this.devActivities = const [],
    this.activityDetails = const [],
    this.devTeamMultipliers = const {},
  });

  String get fullName => '$surname $name ${secondName ?? ''}'.trim();

  /// Recomputes total dev points locally from [devActivities] and [devTeamMultipliers].
  /// Falls back to [totalDevPoints] from the backend if multipliers are not available.
  double? get computedDevPoints {
    if (devTeamMultipliers.isEmpty) return totalDevPoints;
    double total = 0;
    for (final entry in devTeamMultipliers.entries) {
      final teamId = entry.key;
      final projectSum = entry.value;
      final activitySum = devActivities
          .where((a) => a.teamId == teamId)
          .fold<double>(0, (s, a) => s + a.count * (a.type?.points ?? 0));
      total += projectSum * activitySum;
    }
    return double.parse(total.toStringAsFixed(2));
  }

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
      orcidId: json['orcid_id'],
      openalexId: json['openalex_id'],
      github: json['github'],
      totalDevPoints: json['total_dev_points'] != null ? double.tryParse(json['total_dev_points'].toString()) : null,
      isLeader: json['is_leader'] ?? false,
      achievements: (json['achievements'] as List?)
              ?.map((a) => Achievement.fromJson(a))
              .toList() ??
          [],
      devActivities: (json['researcher_dev_activities'] as List?)
              ?.map((a) => ResearcherDevActivity.fromJson(a))
              .toList() ??
          [],
      activityDetails: (json['researcher_activity_details'] as List?)
              ?.map((d) => ResearcherActivityDetail.fromJson(d))
              .toList() ??
          [],
      devTeamMultipliers: {
        for (final m in (json['dev_team_multipliers'] as List? ?? []))
          (m['team_id'] as int): double.tryParse(m['project_sum'].toString()) ?? 0.0
      },
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
      'orcid_id': orcidId,
      'openalex_id': openalexId,
      'github': github,
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
    String? orcidId,
    String? openalexId,
    String? github,
    double? totalDevPoints,
    bool? isLeader,
    List<Achievement>? achievements,
    List<ResearcherDevActivity>? devActivities,
    List<ResearcherActivityDetail>? activityDetails,
    Map<int, double>? devTeamMultipliers,
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
      orcidId: orcidId ?? this.orcidId,
      openalexId: openalexId ?? this.openalexId,
      github: github ?? this.github,
      totalDevPoints: totalDevPoints ?? this.totalDevPoints,
      isLeader: isLeader ?? this.isLeader,
      achievements: achievements ?? this.achievements,
      devActivities: devActivities ?? this.devActivities,
      activityDetails: activityDetails ?? this.activityDetails,
      devTeamMultipliers: devTeamMultipliers ?? this.devTeamMultipliers,
    );
  }
}

class ResearcherActivityDetail {
  final int? id;
  final int? researcherId;
  final int? teamId;
  final String activityType;
  final String externalId;
  final String? title;
  final String? repository;
  final String? url;
  final String? date;
  final String? state;

  ResearcherActivityDetail({
    this.id,
    this.researcherId,
    this.teamId,
    required this.activityType,
    required this.externalId,
    this.title,
    this.repository,
    this.url,
    this.date,
    this.state,
  });

  factory ResearcherActivityDetail.fromJson(Map<String, dynamic> json) {
    return ResearcherActivityDetail(
      id: json['id'],
      researcherId: json['researcher_id'],
      teamId: json['team_id'],
      activityType: json['activity_type']?.toString() ?? '',
      externalId: json['external_id']?.toString() ?? '',
      title: json['title']?.toString(),
      repository: json['repository']?.toString(),
      url: json['url']?.toString(),
      date: json['date']?.toString(),
      state: json['state']?.toString(),
    );
  }
}

class ResearcherDevActivity {
  final int? id;
  final int? researcherId;
  final int? teamId;
  final int devEmployeeActivityTypeId;
  final int count;
  final String? date;
  final DateTime? createdAt;
  final DevEmployeeActivityType? type;

  ResearcherDevActivity({
    this.id,
    this.researcherId,
    this.teamId,
    required this.devEmployeeActivityTypeId,
    required this.count,
    this.date,
    this.createdAt,
    this.type,
  });

  factory ResearcherDevActivity.fromJson(Map<String, dynamic> json) {
    return ResearcherDevActivity(
      id: json['id'],
      researcherId: json['researcher_id'],
      teamId: json['team_id'],
      devEmployeeActivityTypeId: json['dev_employee_activity_type_id'],
      count: json['count'] ?? 0,
      date: json['date'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      type: json['dev_employee_activity_type'] != null ? DevEmployeeActivityType.fromJson(json['dev_employee_activity_type']) : null,
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
      points: json['points'] != null ? double.tryParse(json['points'].toString()) : null,
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
  final double? devCriteriaSum;
  final double? devActivitiesSum;
  final String? githubRepoUrl;
  final List<DevProjectCriterion>? devProjectCriteria;

  Team({
    this.id,
    required this.title,
    this.leaderId,
    this.leader,
    this.researchers,
    this.devCriteriaSum,
    this.devActivitiesSum,
    this.githubRepoUrl,
    this.devProjectCriteria,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    final researchersJson = json['researchers'] as List?;
    final List<Researcher>? researchers = researchersJson != null
        ? researchersJson.map((r) => Researcher.fromJson(r)).toList()
        : null;
    researchers?.sort(Researcher.compareByFullName);

    final criteriaJson = json['dev_project_criteria'] as List?;

    return Team(
      id: json['id'],
      title: json['title'] ?? '',
      leaderId: json['leader_id'],
      leader: json['leader'] != null ? Researcher.fromJson(json['leader']) : null,
      researchers: researchers,
      devCriteriaSum: json['dev_criteria_sum'] != null ? double.tryParse(json['dev_criteria_sum'].toString()) : null,
      devActivitiesSum: json['dev_activities_sum'] != null ? double.tryParse(json['dev_activities_sum'].toString()) : null,
      githubRepoUrl: json['github_repo_url'],
      devProjectCriteria: criteriaJson?.map((c) => DevProjectCriterion.fromJson(c)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'leader_id': leaderId,
      'github_repo_url': githubRepoUrl,
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

class GitHubCheckKey {
  final String key;
  final String label;
  final String category;

  const GitHubCheckKey({required this.key, required this.label, required this.category});

  factory GitHubCheckKey.fromJson(Map<String, dynamic> json) {
    return GitHubCheckKey(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class GitHubCheckKeysRegistry {
  final List<GitHubCheckKey> criteriaKeys;
  final List<GitHubCheckKey> activityKeys;
  final Map<String, String> categoryLabels;

  const GitHubCheckKeysRegistry({
    required this.criteriaKeys,
    required this.activityKeys,
    required this.categoryLabels,
  });

  factory GitHubCheckKeysRegistry.fromJson(Map<String, dynamic> json) {
    return GitHubCheckKeysRegistry(
      criteriaKeys: (json['criteria_keys'] as List? ?? [])
          .map((e) => GitHubCheckKey.fromJson(e))
          .toList(),
      activityKeys: (json['activity_keys'] as List? ?? [])
          .map((e) => GitHubCheckKey.fromJson(e))
          .toList(),
      categoryLabels: Map<String, String>.from(json['category_labels'] ?? {}),
    );
  }

  String labelFor(String key) {
    for (final k in [...criteriaKeys, ...activityKeys]) {
      if (k.key == key) return k.label;
    }
    return key;
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
