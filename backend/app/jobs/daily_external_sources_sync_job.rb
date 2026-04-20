# frozen_string_literal: true

# Ежедневная синхронизация внешних источников по всем исследователям и командам:
# ORCID + OpenAlex (all), GitHub (сотрудники и команды), интернет-краулер по всем исследователям (crawl_search).
# Отключить краулер: ENV DAILY_SYNC_EXCLUDE_CRAWL=true (дорого по LLM/времени).
class DailyExternalSourcesSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :integrations, retry: 1

  def perform
    cancel_proc = -> { false }
    total_saved = 0

    phases.each do |name, params|
      merged = params.merge(cancel_proc: cancel_proc)
      result = Integrations::SyncPreviewCommand.call(merged)
      if result.failure?
        Rails.logger.error "[DailyExternalSourcesSync] phase #{name} failed: #{result.failure.inspect}"
        next
      end

      rows = Array(result.value!['results'])
      ach, rdev, tdev = split_preview_rows(rows)
      stats = Integrations::PersistSyncResultsService.call(
        achievements: ach,
        researcher_dev_data: rdev,
        team_dev_data: tdev
      )
      total_saved += stats[:saved_count].to_i
      Rails.logger.info "[DailyExternalSourcesSync] phase #{name}: saved #{stats[:saved_count]} achievements " \
                        "(rows: #{rows.size})"
    rescue StandardError => e
      Rails.logger.error "[DailyExternalSourcesSync] phase #{name} error: #{e.class}: #{e.message}"
    end

    Rails.logger.info "[DailyExternalSourcesSync] finished, total new achievements saved: #{total_saved}"
  end

  private

  def phases
    list = [
      ['academic_all', { provider: 'all' }],
      ['github_researchers', { provider: 'github' }],
      ['github_teams', { provider: 'github', scope: 'teams' }]
    ]
    list << ['crawl_researchers', { provider: 'crawl_search' }] unless exclude_crawl?
    list.concat(team_crawl_phases) unless exclude_crawl?
    list
  end

  def exclude_crawl?
    ENV['DAILY_SYNC_EXCLUDE_CRAWL'].to_s == 'true'
  end

  # Краулер по командам (в SyncPreview нет scope: teams для crawl, только по team_id).
  def team_crawl_phases
    Team.pluck(:id).map { |tid| ["crawl_team_#{tid}", { provider: 'crawl_search', team_id: tid }] }
  end

  # Разбивает строки предпросмотра на аргументы PersistSyncResultsService (как во Flutter sync_preview_dialog).
  def split_preview_rows(rows)
    achievements = []
    researcher_dev_data = []
    team_dev_data = []

    Array(rows).each do |row|
      r = row.is_a?(Hash) ? row.stringify_keys : {}
      rid = r['researcher_id']
      tid = r['team_id']

      Array(r['achievements']).each do |ach|
        a = ach.is_a?(Hash) ? ach.stringify_keys : {}
        a['researcher_id'] ||= rid
        achievements << a if a['researcher_id'].present?
      end

      if rid.present? && ((r['dev_activities'].present?) || (r['activity_details'].present?) ||
          (r['project_criteria_met'].present?))
        researcher_dev_data << {
          'researcher_id' => rid,
          'dev_activities' => r['dev_activities'] || [],
          'project_criteria_met' => r['project_criteria_met'] || [],
          'activity_details' => r['activity_details'] || []
        }
      end

      next unless tid.present? && ((r['dev_activities'].present?) || (r['project_criteria_met'].present?))

      team_dev_data << {
        'team_id' => tid,
        'dev_activities' => r['dev_activities'] || [],
        'project_criteria_met' => r['project_criteria_met'] || []
      }
    end

    [achievements, researcher_dev_data, team_dev_data]
  end
end
