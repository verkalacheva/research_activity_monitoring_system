import 'achievement_field_answer.dart';
import 'achievement_refs.dart';
import 'achievement_type.dart';

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
