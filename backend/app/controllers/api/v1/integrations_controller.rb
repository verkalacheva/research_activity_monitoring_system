module Api
  module V1
    class IntegrationsController < BaseController
      def save_achievements
        achievements_params = params[:achievements] || []
        researcher_dev_data = params[:researcher_dev_data] || []
        team_dev_data = params[:team_dev_data] || []
        saved_count = 0
        
        achievements_params.each do |attr|
          res_id = attr[:researcher_id]
          next unless res_id
          
          type = map_type(attr[:type])
          status = map_status(attr[:title], attr[:description], attr[:url])
          result = map_result(attr[:title], attr[:description])
          participation = map_participation(attr[:title], attr[:author_count], attr[:description], attr[:journal_title])
          
          achievement = Achievement.new(
            achievement_type: type,
            achievement_status: status,
            achievement_result: result,
            achievement_participation: participation,
            submission_date: attr[:date].present? ? (parse_achievement_date(attr[:date]) rescue Time.current) : Time.current
          )
          
          if achievement.save
            ResearcherAchievement.create!(researcher_id: res_id, achievement: achievement)

            extra_fields = attr[:extra_fields].presence || {}

            type.achievement_fields.each do |field|
              value = extra_fields[field.title].presence

              value ||= case field.title
                        when /полное название статьи/i, /название рид/i, /название темы выступления/i,
                             /полное название хакатона/i, /полное название конкурса/i,
                             /название программы/i, /название достижения/i
                          attr[:title]
                        when /полное название журнала/i, /полное название мероприятия/i,
                             /юридическое название организации/i, /название сми/i
                          attr[:journal_title].presence || attr[:description]
                        when /дата/i
                          attr[:date].present? ? parse_achievement_date(attr[:date]).to_s : nil
                        when /ссылка/i, /документ/i, /библиографическая/i
                          attr[:url].presence || attr[:external_id]
                        when /степень участия/i, /полное описание/i, /упоминание/i
                          attr[:description]
                        end

              if value.present?
                achievement.achievement_field_answers.create!(achievement_field: field, value: value)
              end
            end
            saved_count += 1
          end
        end

        researcher_dev_data.each do |rd|
          save_researcher_dev_data(rd[:researcher_id], rd[:dev_activities] || [], rd[:activity_details] || [])
        end

        team_dev_data.each do |td|
          save_team_dev_data(td[:team_id], td[:dev_activities] || [], td[:project_criteria_met] || [])
        end

        render json: { saved_count: saved_count, message: "Успешно сохранено #{saved_count} достижений и данные по разработке" }
      end

      private

      # Parses ISO 8601 dates returned by the crawler (YYYY-MM-DD, YYYY-MM, or YYYY).
      # Always returns a Date so callers don't need to rescue individually.
      def parse_achievement_date(raw)
        str = raw.to_s.strip
        case str
        when /\A\d{4}-\d{2}-\d{2}\z/   # YYYY-MM-DD
          Date.parse(str)
        when /\A\d{4}-\d{2}\z/          # YYYY-MM
          Date.parse("#{str}-01")
        when /\A\d{4}\z/                # YYYY
          Date.parse("#{str}-01-01")
        else
          Date.parse(str)               # let Ruby try arbitrary formats
        end
      end

      def save_researcher_dev_data(researcher_id, dev_activities, activity_details = [])
        return unless researcher_id.present?
        researcher = Researcher.find_by(id: researcher_id)
        return unless researcher

        team = researcher.teams.first
        return unless team

        activity_details.each do |ad|
          ext_id = ad[:external_id].to_s
          act_type = ad[:activity_type].to_s
          next if ext_id.blank? || act_type.blank?

          ResearcherActivityDetail.find_or_create_by(
            external_id: ext_id,
            activity_type: act_type,
            researcher: researcher
          ) do |d|
            d.team = team
            d.title = ad[:title].to_s
            d.repository = ad[:repository].to_s
            d.url = ad[:url].to_s
            d.state = ad[:state].to_s
            d.date = ad[:date].present? ? (Date.parse(ad[:date]) rescue nil) : nil
          end
        end

        dev_activities.each do |da|
          type = DevEmployeeActivityType.find_by(title: da[:activity_type])
          next unless type

          date = da[:date].present? ? (begin Date.parse(da[:date]); rescue; Date.current; end) : Date.current
          new_count = da[:count].to_i
          # Нет данных по этому типу у сотрудника — не сохраняем строку с count 0.
          next if new_count.zero?

          if GithubCheckKeys::SNAPSHOT_CHECK_KEYS.include?(type.check_key)
            # Snapshot metric: GitHub returns the current cumulative total (e.g. "150 followers now").
            # Compute the delta vs everything already saved (excluding today's row so same-day
            # re-syncs recalculate correctly without compounding).
            historical_sum = ResearcherDevActivity
              .where(researcher: researcher, team: team, dev_employee_activity_type: type)
              .where.not(date: date)
              .sum(:count)

            delta = new_count - historical_sum
            next if delta == 0

            act = ResearcherDevActivity.find_or_initialize_by(
              researcher: researcher, team: team,
              dev_employee_activity_type: type, date: date
            )
            act.count = delta
            act.save
          else
            # Event-based metric: GitHub groups real events by their creation date
            # (e.g. 5 commits on 2024-01-15).  The unique index on
            # (researcher, team, type, date) already prevents duplicates — a re-sync
            # on the same day just overwrites the record with the identical value.
            act = ResearcherDevActivity.find_or_initialize_by(
              researcher: researcher, team: team,
              dev_employee_activity_type: type, date: date
            )
            act.count = new_count
            act.save
          end
        end
      end

      def save_team_dev_data(team_id, dev_activities, project_criteria)
        return unless team_id.present?
        team = Team.find_by(id: team_id)
        return unless team

        dev_activities.each do |da|
          type = DevEmployeeActivityType.find_by(title: da[:activity_type])
          next unless type

          date = da[:date].present? ? (begin Date.parse(da[:date]); rescue; Date.current; end) : Date.current
          new_count = da[:count].to_i
          next if new_count.zero?

          if GithubCheckKeys::SNAPSHOT_CHECK_KEYS.include?(type.check_key)
            historical_sum = TeamDevActivity
              .where(team: team, dev_employee_activity_type: type)
              .where.not(date: date)
              .sum(:count)

            delta = new_count - historical_sum
            next if delta == 0

            act = TeamDevActivity.find_or_initialize_by(
              team: team, dev_employee_activity_type: type, date: date
            )
            act.count = delta
            act.save
          else
            act = TeamDevActivity.find_or_initialize_by(
              team: team, dev_employee_activity_type: type, date: date
            )
            act.count = new_count
            act.save
          end
        end

        project_criteria.each do |pc_title|
          criterion = DevProjectCriterion.find_by(title: pc_title)
          next unless criterion

          TeamDevCriterion.find_or_create_by!(team: team, dev_project_criterion: criterion)
        end
      end

      def map_type(raw_type)
        return AchievementType.find_by(title: 'Другое') || AchievementType.first unless raw_type.present?

        normalized = raw_type.to_s.strip

        # 1. Точное совпадение без учёта регистра
        found = AchievementType.find_by("lower(title) = ?", normalized.downcase)
        return found if found

        # 2. Тип содержит название из БД или наоборот
        found = AchievementType.all.find do |t|
          normalized.downcase.include?(t.title.downcase) ||
          t.title.downcase.include?(normalized.downcase)
        end
        return found if found

        # 3. Keyword-фолбэк для английских и смешанных названий
        title = case normalized.downcase
                when /article|journal|paper|working.paper|статья|публикация/ then 'Статья'
                when /conference|конференция|presentation|lecture|выступление|тезис/ then 'Конференция'
                when /patent|рид|intellectual|rid|свидетельство|регистрация/ then 'РИД'
                when /grant|грант|funding|финансирование/ then 'Грант'
                when /hackathon|хакатон/ then 'Хакатон'
                when /award|prize|honor|награда|победа|medal/ then 'Хакатон'
                when /stipend|стипендия|scholarship/ then 'Стипендия'
                when /intern|стажировка/ then 'Стажировка'
                when /mentor|наставник/ then 'Наставничество/менторство'
                when /media|сми|упоминание|новость/ then 'Упоминание в СМИ'
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
          AchievementStatus.find_by(title: 'Не указано') || AchievementStatus.find_by(title: 'Университетский') || AchievementStatus.first
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
