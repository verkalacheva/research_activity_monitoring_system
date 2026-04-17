/// Non-translatable report configuration: API field names for filters and sort keys.
/// Human-readable labels live in `assets/l10n/*.yaml` (see [AppStrings.reportTitles], etc.).
abstract final class ReportUiConstants {
  static const Map<String, List<String>> reportFilters = {
    'researchers_report': ['submission_date', 'researcher_id', 'team_id', 'status', 'achievement_result_id', 'achievement_participation_id'],
    'teams': ['submission_date', 'team_id'],
    'dev_teams_report': ['activity_date', 'team_id'],
    'dev_researchers_report': ['activity_date', 'researcher_id', 'team_id'],
  };

  static const Map<String, List<String>> reportSorts = {
    'researchers_report': ['r.surname', 'a.points', 'dev_points', 'combined_points', 'id'],
    'teams': ['title', 'total_points', 'dev_points', 'combined_points', 'members_count', 'id'],
    'dev_teams_report': ['team', 'total_score', 'criteria_sum', 'criteria_list', 'activity_sum'],
    'dev_researchers_report': ['researcher', 'team', 'dev_points', 'criteria_sum', 'activity_type', 'activity_points'],
  };
}
