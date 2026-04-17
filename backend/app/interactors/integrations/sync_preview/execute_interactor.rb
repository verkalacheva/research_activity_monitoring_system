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
          team = Team.find(team_id)
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
          team_data = Team.where.not(github_repo_url: [nil, ''])
                          .map { |t| { id: t.id, title: t.title, url: t.github_repo_url } }

          threads = team_data.map do |t|
            Thread.new do
              begin
                resp = Integrations::Client.github_dev_activity(t[:url], nil, t[:id], cancel_proc: @cancel_proc)
                next nil unless resp
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
            end
          end

          threads.map(&:value).compact
        else
          researcher_data = Researcher.where.not(github: [nil, ''])
                                        .map { |r| { id: r.id, name: r.fullName, github: r.github } }

          threads = researcher_data.map do |r|
            Thread.new do
              begin
                resp = Integrations::Client.github_dev_activity(r[:github], r[:id], nil, cancel_proc: @cancel_proc)
                next nil unless resp
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

          threads.map(&:value).compact
        end
      end

      def internet_crawl_sync_rows
        llm_provider = @params[:llm_provider]
        researcher_id = @params[:researcher_id]
        team_id = @params[:team_id]

        if team_id.present?
          team = Team.find(team_id)
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
          researcher = Researcher.find(researcher_id)
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
          researchers = Researcher.all
          results = []
          researchers.each do |r|
            break if @cancel_proc.call
            begin
              resp = Integrations::Client.crawl(nil, r.id, r.fullName, true, llm_provider, r.github, cancel_proc: @cancel_proc)
              next unless resp

              new_achievements = filter_new_achievements(r.id, resp.achievements)
              dev_acts = resp.dev_activities.map { |da| { activity_type: da.activity_type, count: da.count, date: da.date } }
              warns = resp.warnings.to_a

              next if new_achievements.empty? && dev_acts.empty? && warns.empty?

              results << {
                researcher_id: r.id,
                researcher_name: r.fullName,
                achievements: new_achievements,
                dev_activities: dev_acts,
                project_criteria_met: resp.project_criteria_met.to_a,
                warnings: warns
              }
            rescue StandardError => e
              msg = e.message.to_s.force_encoding('UTF-8')
              Rails.logger.error "Failed to sync for #{r.fullName}: #{msg}"
            end
          end
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
    end
  end
end
