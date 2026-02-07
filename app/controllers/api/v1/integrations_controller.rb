module Api
  module V1
    class IntegrationsController < BaseController
      def sync_preview
        provider = params[:provider] || 'orcid'
        response = Integrations::Client.sync_all(provider)
        
        results = response.results.map do |res|
          researcher = Researcher.find_by(id: res.researcher_id)
          next nil unless researcher

          # Собираем все существующие значения полей (названия, ссылки, ID) для активных достижений
          existing_values = AchievementFieldAnswer.joins(achievement: :researchers)
                                                 .where(researchers: { id: res.researcher_id })
                                                 .where(achievements: { deleted_at: nil })
                                                 .where(achievement_field_answers: { deleted_at: nil })
                                                 .pluck(:value).map(&:downcase).to_set

          # Фильтруем: оставляем только те, которых нет в базе
          new_achievements = res.achievements.reject do |a|
            existing_values.include?(a.title.to_s.downcase) || 
            (a.external_id.present? && existing_values.include?(a.external_id.to_s.downcase)) ||
            (a.url.present? && existing_values.include?(a.url.to_s.downcase))
          end

          next nil if new_achievements.empty?

          {
            researcher_id: res.researcher_id,
            orcid_id: res.orcid_id,
            researcher_name: researcher.fullName,
            achievements: new_achievements.map do |a|
              {
                title: a.title,
                type: a.type,
                external_id: a.external_id,
                url: a.url,
                date: a.date,
                description: a.description,
                author_count: a.author_count,
                journal_title: a.journal_title
              }
            end
          }
        end.compact
        
        render json: { results: results }
      rescue GRPC::BadStatus => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def save_achievements
        # ... (код сохранения остается прежним)
        achievements_params = params[:achievements] || []
        saved_count = 0
        
        achievements_params.each do |attr|
          type = map_type(attr[:type])
          status = map_status(attr[:title], attr[:description], attr[:url])
          result = map_result(attr[:title], attr[:description])
          participation = map_participation(attr[:title], attr[:author_count], attr[:description], attr[:journal_title])
          
          achievement = Achievement.new(
            achievement_type: type,
            achievement_status: status,
            achievement_result: result,
            achievement_participation: participation,
            submission_date: attr[:date].present? ? Date.parse("#{attr[:date]}-01-01") : Time.current
          )
          
          if achievement.save
            ResearcherAchievement.create!(researcher_id: attr[:researcher_id], achievement: achievement)
            
            type.achievement_fields.each do |field|
              value = case field.title.downcase
                      when /название.*статьи/i, /название.*рид/i, /название.*темы/i, /^название$/i
                        attr[:title]
                      when /название.*журнала/i, /название.*мероприятия/i, /организация/i
                        attr[:journal_title].presence || attr[:description]
                      when /дата/i
                        attr[:date].present? ? "#{attr[:date]}-01-01" : nil
                      when /ссылка/i, /документ/i
                        attr[:url].presence || attr[:external_id]
                      when /степень участия/i, /описание/i
                        attr[:description]
                      end
              
              if value.present?
                achievement.achievement_field_answers.create!(achievement_field: field, value: value)
              end
            end
            saved_count += 1
          end
        end
        render json: { saved_count: saved_count, message: "Успешно сохранено #{saved_count} достижений" }
      end

      private
      # ... (методы map_* остаются без изменений)
      def map_type(orcid_type)
        title = case orcid_type.to_s.downcase
                when /article/, /book/, /chapter/, /paper/, /working-paper/, /conference-paper/ then 'Статья'
                when /conference/ then 'Конференция'
                when /patent/ then 'РИД'
                else 'Другое'
                end
        AchievementType.find_by(title: title) || AchievementType.find_by(title: 'Другое') || AchievementType.first
      end

      def map_status(title, description, url)
        text = "#{title} #{description} #{url}".downcase
        if text.include?('scopus') || text.include?('web of science') || text.include?('wos') || text.include?('elsevier')
          AchievementStatus.find_by(title: 'Scopus/Web of Science')
        elsif text.include?('international') || text.include?('международн')
          AchievementStatus.find_by(title: 'Международный')
        elsif text.include?('ваг') || text.include?('vak')
          AchievementStatus.find_by(title: 'ВАК')
        elsif text.include?('rsci')
          AchievementStatus.find_by(title: 'RSCI')
        else
          AchievementStatus.find_by(title: 'Университетский') || AchievementStatus.first
        end
      end

      def map_result(title, description)
        text = "#{title} #{description}".downcase
        if text.include?('q1')
          AchievementResult.find_by(title: 'Q1 (K1 для RSCI)')
        elsif text.include?('q2')
          AchievementResult.find_by(title: 'Q2 (K2)')
        elsif text.include?('побед') || text.include?('winner') || text.include?('1 место')
          AchievementResult.find_by(title: 'Победа')
        else
          AchievementResult.find_by(title: 'Участие') || AchievementResult.first
        end
      end

      def map_participation(title, author_count, description, journal_title = nil)
        text = "#{title} #{description} #{journal_title}".downcase
        if author_count.to_i > 1 || 
           text.include?('contributors') || 
           text.include?('et al') || 
           text.include?(';')
          AchievementParticipation.find_by(title: 'Коллективный')
        else
          AchievementParticipation.find_by(title: 'Индивидуальный') || AchievementParticipation.first
        end
      end
    end
  end
end
