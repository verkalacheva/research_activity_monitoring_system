# frozen_string_literal: true

module Integrations
  module SyncPreview
    # Сбор предпросмотра синхронизации по провайдеру (ORCID, OpenAlex, интернет-краулер, GitHub, sync_all).
    # GitHub для сотрудников/команд идёт только через integration_service (github_dev_activity), без веб-краулера.
    class ExecuteInteractor < BaseInteractor
      def call(params:, cancel_proc:)
        @params = params
        @cancel_proc = cancel_proc
        success(execute_core)
      end

      private

      def execute_core
        provider = @params[:provider].presence || 'orcid'
        researcher_id = @params[:researcher_id]
        team_id = @params[:team_id]

        if researcher_id.present? && %w[orcid openalex].include?(provider.to_s)
          return single_researcher_academic_sync(provider.to_s, researcher_id)
        end

        return github_dev_sync_rows if provider.to_s == 'github'
        return internet_crawl_sync_rows if %w[crawl crawl_search].include?(provider.to_s)

        response = Integrations::Client.sync_all(provider.to_s, cancel_proc: @cancel_proc)
        return [] unless response

        response.results.map do |res|
          researcher = Researcher.find_by(id: res.researcher_id)
          next nil unless researcher

          {
            researcher_id: res.researcher_id,
            orcid_id: res.orcid_id,
            openalex_id: res.openalex_id,
            researcher_name: researcher.fullName,
            achievements: filter_new_achievements(res.researcher_id, res.achievements)
          }
        end.compact.reject { |r| r[:achievements].empty? }
      end

      def github_dev_sync_rows
        researcher_id = @params[:researcher_id]
        team_id = @params[:team_id]

        if team_id.present?
          team = Team.kept.find_by(id: team_id)
          return [] unless team
          response = Integrations::Client.github_dev_activity(team.github_repo_url, nil, team_id, cancel_proc: @cancel_proc)
          return [] unless response

          [{
            team_id: team_id.to_i,
            team_title: team.title,
            dev_activities: response.activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
            project_criteria_met: response.project_criteria_met.to_a,
            activity_details: response.activity_details.map { |ad|
              { activity_type: ad.activity_type, external_id: ad.external_id, title: ad.title, repository: ad.repository, url: ad.url, date: ad.date, state: ad.state }
            }
          }]
        elsif researcher_id.present?
          researcher = Researcher.find(researcher_id)
          response = Integrations::Client.github_dev_activity(researcher.github, researcher_id, nil, cancel_proc: @cancel_proc)
          return [] unless response

          [{
            researcher_id: researcher_id.to_i,
            researcher_name: researcher.fullName,
            achievements: [],
            dev_activities: response.activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
            project_criteria_met: [],
            activity_details: response.activity_details.map { |ad|
              { activity_type: ad.activity_type, external_id: ad.external_id, title: ad.title, repository: ad.repository, url: ad.url, date: ad.date, state: ad.state }
            }
          }]
        elsif @params[:scope].to_s == 'teams'
          team_jobs = ActiveRecord::Base.connection_pool.with_connection do
            Team.kept.where.not(github_repo_url: [nil, '']).map do |t|
              { id: t.id, title: t.title, url: t.github_repo_url }
            end
          end

          job_procs = team_jobs.map do |t|
            -> { github_sync_team_row(t) }
          end
          bounded_github_sync(job_procs)
        else
          researcher_jobs = ActiveRecord::Base.connection_pool.with_connection do
            Researcher.where.not(github: [nil, '']).map do |r|
              { id: r.id, name: r.fullName, github: r.github }
            end
          end

          job_procs = researcher_jobs.map do |r|
            -> { github_sync_researcher_row(r) }
          end
          bounded_github_sync(job_procs)
        end
      end

      def internet_crawl_sync_rows
        llm_provider = @params[:llm_provider]
        researcher_id = @params[:researcher_id]
        team_id = @params[:team_id]

        if team_id.present?
          team = Team.kept.find_by(id: team_id)
          return [] unless team
          response = Integrations::Client.crawl(nil, nil, team.title.to_s, true, nil, nil, cancel_proc: @cancel_proc)
          return [] unless response

          [{
            team_id: team_id.to_i,
            team_title: team.title,
            dev_activities: response.dev_activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
            project_criteria_met: response.project_criteria_met.to_a,
            warnings: response.warnings.to_a
          }]
        elsif researcher_id.present?
          researcher = Researcher.kept.find_by(id: researcher_id)
          return [] unless researcher
          response = Integrations::Client.crawl(nil, researcher_id, researcher.fullName, true, llm_provider, researcher.github, cancel_proc: @cancel_proc)
          return [] unless response

          raw_achievements = response.achievements.to_a
          new_achievements = filter_new_achievements(researcher_id, raw_achievements)
          warnings = Array(response.warnings).dup
          if raw_achievements.any? && new_achievements.empty?
            warnings << "Краулер нашёл #{raw_achievements.size} достижений, но ни одно не показано к импорту: " \
                         "все совпали с уже сохранёнными полями профиля (дедупликация по названию, ссылкам и т.п.)."
          end

          rows = [{
            researcher_id: researcher_id.to_i,
            researcher_name: researcher.fullName,
            achievements: new_achievements,
            dev_activities: response.dev_activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
            project_criteria_met: response.project_criteria_met.to_a,
            warnings: warnings
          }]
          rows.reject do |r|
            r[:achievements].empty? && r[:dev_activities].empty? && r[:project_criteria_met].empty? &&
              r[:warnings].blank?
          end
        else
          crawl_jobs = ActiveRecord::Base.connection_pool.with_connection do
            Researcher.kept.order(:id).map do |r|
              { id: r.id, fullName: r.fullName, github: r.github }
            end
          end
          results = []
          results_mutex = Mutex.new
          work_mutex = Mutex.new
          concurrency = begin
            n = ENV.fetch('DAILY_CRAWL_CONCURRENCY', '4').to_i
            n < 1 ? 1 : n
          end
          workers = concurrency.times.map do
            Thread.new do
              loop do
                break if @cancel_proc.call

                job = work_mutex.synchronize { crawl_jobs.shift }
                break unless job

                begin
                  resp = Integrations::Client.crawl(nil, job[:id], job[:fullName], true, llm_provider, job[:github].to_s,
                                                      cancel_proc: @cancel_proc)
                  next unless resp

                  new_achievements = ActiveRecord::Base.connection_pool.with_connection do
                    filter_new_achievements(job[:id], resp.achievements)
                  end
                  dev_acts = resp.dev_activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } }
                  warns = resp.warnings.to_a

                  next if new_achievements.empty? && dev_acts.empty? && warns.empty?

                  row = {
                    researcher_id: job[:id],
                    researcher_name: job[:fullName],
                    achievements: new_achievements,
                    dev_activities: dev_acts,
                    project_criteria_met: resp.project_criteria_met.to_a,
                    warnings: warns
                  }
                  results_mutex.synchronize { results << row }
                rescue StandardError => e
                  msg = e.message.to_s.force_encoding('UTF-8')
                  Rails.logger.error "Failed to sync for #{job[:fullName]}: #{msg}"
                end
              end
            end
          end
          workers.each(&:join)
          results
        end
      end

      def single_researcher_academic_sync(provider, researcher_id)
        researcher = Researcher.find(researcher_id)
        if provider == 'orcid'
          oid = researcher.orcid_id.to_s.strip
          return [] if oid.blank?

          response = Integrations::Client.fetch_orcid_achievements(oid, cancel_proc: @cancel_proc)
          return [] unless response

          ach = filter_new_achievements(researcher.id, response.achievements)
          return [] if ach.empty?

          [{
            researcher_id: researcher.id,
            researcher_name: researcher.fullName,
            orcid_id: oid,
            openalex_id: researcher.openalex_id,
            achievements: ach
          }]
        else
          oax = researcher.openalex_id.to_s.strip
          return [] if oax.blank?

          response = Integrations::Client.fetch_open_alex_achievements(oax, cancel_proc: @cancel_proc)
          return [] unless response

          ach = filter_new_achievements(researcher.id, response.achievements)
          return [] if ach.empty?

          [{
            researcher_id: researcher.id,
            researcher_name: researcher.fullName,
            orcid_id: researcher.orcid_id,
            openalex_id: oax,
            achievements: ach
          }]
        end
      end

      def filter_new_achievements(researcher_id, achievements)
        FilterNewAchievementsInteractor.call(researcher_id: researcher_id, achievements: achievements).value!
      end

      # Ограниченный пул потоков для GitHub: не порождаем по потоку на каждого исследователя (и не держим AR на главном потоке).
      def bounded_github_sync(job_procs)
        return [] if job_procs.empty?

        concurrency = begin
          n = ENV.fetch('GITHUB_DEV_SYNC_CONCURRENCY', '8').to_i
          n < 1 ? 1 : n
        end
        concurrency = [concurrency, job_procs.size].min
        pending = job_procs.dup
        lock = Mutex.new
        out = []
        out_m = Mutex.new
        workers = concurrency.times.map do
          Thread.new do
            loop do
              jp = lock.synchronize { pending.shift }
              break unless jp

              row = jp.call
              out_m.synchronize { out << row } unless row.nil?
            end
          end
        end
        workers.each(&:join)
        out.compact
      end

      def github_sync_team_row(t)
        resp = Integrations::Client.github_dev_activity(t[:url], nil, t[:id], cancel_proc: @cancel_proc)
        return nil unless resp

        {
          team_id: t[:id],
          team_title: t[:title],
          dev_activities: resp.activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
          project_criteria_met: resp.project_criteria_met.to_a,
          activity_details: resp.activity_details.map { |ad|
            { activity_type: ad.activity_type, external_id: ad.external_id, title: ad.title, repository: ad.repository, url: ad.url, date: ad.date, state: ad.state }
          }
        }
      rescue StandardError => e
        Rails.logger.error "Failed to sync GitHub for team #{t[:title]}: #{e.message.to_s.force_encoding('UTF-8')}"
        nil
      end

      def github_sync_researcher_row(r)
        resp = Integrations::Client.github_dev_activity(r[:github], r[:id], nil, cancel_proc: @cancel_proc)
        return nil unless resp

        {
          researcher_id: r[:id],
          researcher_name: r[:name],
          achievements: [],
          dev_activities: resp.activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } },
          project_criteria_met: [],
          activity_details: resp.activity_details.map { |ad|
            { activity_type: ad.activity_type, external_id: ad.external_id, title: ad.title, repository: ad.repository, url: ad.url, date: ad.date, state: ad.state }
          }
        }
      rescue StandardError => e
        Rails.logger.error "Failed to sync GitHub for researcher #{r[:name]}: #{e.message.to_s.force_encoding('UTF-8')}"
        nil
      end
    end
  end
end
