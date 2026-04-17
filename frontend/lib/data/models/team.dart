import 'dev_models.dart';
import 'researcher.dart';

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
