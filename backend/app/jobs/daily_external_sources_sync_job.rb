# frozen_string_literal: true

# Ежедневная синхронизация внешних источников:
# ORCID + OpenAlex (all), GitHub (сотрудники и команды), интернет-краулер по исследователям (crawl_search).
# Фазы выполняются параллельно (отдельные потоки; внешние вызовы не удерживают пул соединений БД).
# Результаты не пишутся в БД сразу: кладутся в Redis (как после ручного предпросмотра), чтобы в приложении
# показался колокольчик и окно SyncPreviewDialog с тем же сценарием сохранения.
# Краулер по командам в эту задачу не входит (только по исследователям).
# Отключить краулер: ENV DAILY_SYNC_EXCLUDE_CRAWL=true (дорого по LLM/времени).
class DailyExternalSourcesSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :integrations, retry: 1

  DAILY_SYNC_LABEL = 'Ежедневная синхронизация'

  def perform
    cancel_proc = -> { false }
    total_rows = 0

    User.active.find_each do |admin|
      rows = sync_phases_for_admin(admin, cancel_proc)
      next if rows.empty?

      entry = {
        'provider' => 'daily_sync',
        'label' => DAILY_SYNC_LABEL,
        'results' => rows,
        'has_error' => false,
        'admin_id' => admin.id
      }
      Integrations::PendingSyncResultsStore.replace_daily_sync_entry(entry, admin_id: admin.id)
      total_rows += rows.size
      Rails.logger.info "[DailyExternalSourcesSync] admin #{admin.id}: #{rows.size} preview rows queued"
    end

    if total_rows.zero?
      Rails.logger.info '[DailyExternalSourcesSync] finished, no preview rows (nothing to show)'
    else
      Rails.logger.info "[DailyExternalSourcesSync] finished, #{total_rows} preview rows queued for review (Redis)"
    end
  rescue StandardError => e
    Rails.logger.error "[DailyExternalSourcesSync] failed to store preview: #{e.class}: #{e.message}"
  end

  private

  def sync_phases_for_admin(admin, cancel_proc)
    all_rows = []
    rows_mutex = Mutex.new

    threads = phases.map do |name, params|
      TenantContext.in_thread(admin) do
        begin
          merged = params.merge(cancel_proc: cancel_proc)
          result = Integrations::SyncPreviewCommand.call(merged)
          if result.failure?
            Rails.logger.error "[DailyExternalSourcesSync] admin #{admin.id} phase #{name} failed: #{result.failure.inspect}"
          else
            rows = Array(result.value!['results'])
            rows_mutex.synchronize { all_rows.concat(rows) }
            Rails.logger.info "[DailyExternalSourcesSync] admin #{admin.id} phase #{name}: preview rows #{rows.size}"
          end
        rescue StandardError => e
          Rails.logger.error "[DailyExternalSourcesSync] admin #{admin.id} phase #{name} error: #{e.class}: #{e.message}"
        end
      end
    end

    threads.each(&:join)
    all_rows
  end

  def phases
    list = [
      ['academic_all', { provider: 'all' }],
      ['github_researchers', { provider: 'github' }],
      ['github_teams', { provider: 'github', scope: 'teams' }]
    ]
    list << ['crawl_researchers', { provider: 'crawl_search' }] unless exclude_crawl?
    list
  end

  def exclude_crawl?
    ENV['DAILY_SYNC_EXCLUDE_CRAWL'].to_s == 'true'
  end
end
