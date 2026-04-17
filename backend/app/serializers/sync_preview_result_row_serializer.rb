# frozen_string_literal: true

# Одна запись в results (сотрудник, команда или блок dev-данных).
class SyncPreviewResultRowSerializer < BaseSerializer
  def to_h
    row = object.is_a?(Hash) ? object.deep_stringify_keys : {}
    achievements = Array(row['achievements']).map { |ach| SyncPreviewAchievementSerializer.new(ach).to_h }

    {
      'researcher_id' => row['researcher_id'],
      'researcher_name' => row['researcher_name'],
      'team_id' => row['team_id'],
      'team_title' => row['team_title'],
      'orcid_id' => row['orcid_id'],
      'openalex_id' => row['openalex_id'],
      'achievements' => achievements,
      'dev_activities' => Array(row['dev_activities']).map { |d| d.is_a?(Hash) ? d.deep_stringify_keys : d },
      'project_criteria_met' => row['project_criteria_met'] || [],
      'activity_details' => Array(row['activity_details']).map { |d| d.is_a?(Hash) ? d.deep_stringify_keys : d },
      'warnings' => row['warnings'] || []
    }.compact
  end
end
