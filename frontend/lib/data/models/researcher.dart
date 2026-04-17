import 'achievement.dart';
import 'dev_models.dart';

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
