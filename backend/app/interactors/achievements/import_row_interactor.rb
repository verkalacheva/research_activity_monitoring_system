# frozen_string_literal: true

module Achievements
  class ImportRowInteractor < BaseInteractor
    def call(row_pairs:)
      transaction do
        full_name = find_value(row_pairs, 'Ваше ФИО')
        researcher, skip_reason = resolve_researcher_for_import(full_name)
        case skip_reason
        when :missing_name
          return failure(:validation_error, 'ФИО обязательно')
        when :deleted
          return success({ kind: :deleted_researcher_skipped })
        when Array
          return failure(:database_error, skip_reason)
        end
        return failure(:validation_error, "Researcher '#{full_name}' not found or created") unless researcher

        type_title = find_value(row_pairs, 'Тип достижения')
        return failure(:validation_error, 'Achievement type is empty') if type_title.blank?

        type = AchievementType.tenant_find_or_create_by!(Current.admin_id, title: type_title) do |t|
          t.points = 1.0
        end

        status_title = find_value(row_pairs, ['Статус мероприятия', 'Статус'])
        result_title = find_value(row_pairs, 'Результат')
        quartile = find_value(row_pairs, 'Квартиль')
        participation_title = find_value(row_pairs, 'Участие')

        status = find_or_create_status(status_title)
        result_obj = find_or_create_result(result_title, quartile)
        participation = find_or_create_participation(participation_title)

        submission_date = parse_submission_timestamp(find_value(row_pairs, 'Timestamp'))
        answers_attrs = build_answers(type, row_pairs)

        if find_duplicate_achievement(
          researcher.id, type.id, status.id, result_obj.id, participation.id, submission_date, answers_attrs
        )
          return success({ kind: :duplicate_skipped })
        end

        achievement_params = {
          achievement_type_id: type.id,
          achievement_status_id: status.id,
          achievement_result_id: result_obj.id,
          achievement_participation_id: participation.id,
          researcher_ids: [researcher.id],
          submission_date: submission_date&.iso8601,
          achievement_field_answers_attributes: answers_attrs
        }

        create_result = Achievements::CreateCommand.call(achievement_params)
        return create_result if create_result.failure?

        success({ kind: :imported, achievement: create_result.value! })
      end
    end

    private

    def find_value(row_pairs, keys)
      keys = Array(keys)
      row_pairs.each do |key, value|
        return value.strip if keys.include?(key) && value.present?
      end
      nil
    end

    # Returns [researcher, nil] on success, [nil, :missing_name], [nil, :deleted], or [nil, ActiveModel::Errors-like array]
    def resolve_researcher_for_import(full_name)
      return [nil, :missing_name] if full_name.blank?

      parts = full_name.strip.split(/\s+/)
      surname = parts[0]
      name = parts[1] || 'Неизвестно'
      second_name = parts[2..].join(' ') if parts.size > 2

      kept = Researcher.kept.for_current_admin.find_by(surname: surname, name: name, second_name: second_name)
      return [kept, nil] if kept

      return [nil, :deleted] if Researcher.deleted.for_current_admin.find_by(surname: surname, name: name, second_name: second_name)

      researcher = Researcher.create!(surname: surname, name: name, second_name: second_name, admin_id: Current.admin_id)
      [researcher, nil]
    rescue ActiveRecord::RecordInvalid => e
      [nil, e.record.errors.full_messages]
    end

    def find_duplicate_achievement(researcher_id, type_id, status_id, result_id, participation_id, submission_date, answers_attrs)
      rel = Achievement.kept
        .joins(:researchers)
        .where(researchers: { id: researcher_id })
        .where(
          achievement_type_id: type_id,
          achievement_status_id: status_id,
          achievement_result_id: result_id,
          achievement_participation_id: participation_id
        )
      rel = submission_date.nil? ? rel.where(submission_date: nil) : rel.where(submission_date: submission_date)

      desired = answers_signature_from_attributes(answers_attrs)

      rel.includes(:achievement_field_answers).find do |ach|
        answers_signature_from_achievement(ach) == desired
      end
    end

    def answers_signature_from_attributes(answers_attrs)
      answers_attrs.map do |h|
        id = h[:achievement_field_id] || h['achievement_field_id']
        val = h[:value] || h['value']
        [id.to_i, val.to_s.strip]
      end.sort
    end

    def answers_signature_from_achievement(achievement)
      achievement.achievement_field_answers.select(&:kept?).map do |a|
        [a.achievement_field_id, a.value.to_s.strip]
      end.sort
    end

    def find_or_create_status(title)
      title = title.to_s.strip
      scope = AchievementStatus.for_admin_id(Current.admin_id)
      status = scope.find_by('title ILIKE ?', "%#{title}%") if title.present?
      status || AchievementStatus.tenant_find_or_create_by!(Current.admin_id, title: title.presence || 'Не указано') do |s|
        s.points = 1.0
      end
    end

    def find_or_create_result(title, quartile = nil)
      title = title.to_s.strip
      quartile = quartile.to_s.strip

      search_term = quartile.presence || title
      scope = AchievementResult.for_admin_id(Current.admin_id)

      res = scope.find_by('title ILIKE ?', "%#{search_term}%") if search_term.present?
      res || AchievementResult.tenant_find_or_create_by!(Current.admin_id, title: search_term.presence || 'Не указано') do |r|
        r.points = 1.0
      end
    end

    def find_or_create_participation(title)
      title = title.to_s.strip
      scope = AchievementParticipation.for_admin_id(Current.admin_id)
      part = scope.find_by('title ILIKE ?', "%#{title}%") if title.present?
      part || AchievementParticipation.tenant_find_or_create_by!(Current.admin_id, title: title.presence || 'Не указано') do |p|
        p.points = 1.0
      end
    end

    def parse_submission_timestamp(timestamp)
      return nil if timestamp.blank?

      if timestamp.include?('/')
        DateTime.strptime(timestamp, '%m/%d/%Y %H:%M:%S')
      else
        DateTime.parse(timestamp)
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to parse timestamp '#{timestamp}': #{e.message.to_s.force_encoding('UTF-8')}"
      nil
    end

    def build_answers(type, row_pairs)
      type.achievement_fields.map do |field|
        value = find_value(row_pairs, field.title)
        next if value.blank?

        if field.field_type == 'date'
          begin
            if value.include?('/')
              date_part = value.split(' ').first
              parsed_date = Date.strptime(date_part, '%m/%d/%Y')
              value = parsed_date.iso8601
            end
          rescue StandardError => e
            Rails.logger.warn "Failed to parse Google Sheets date '#{value}' for field '#{field.title}': #{e.message.to_s.force_encoding('UTF-8')}"
          end
        end

        { achievement_field_id: field.id, value: value.to_s }
      end.compact
    end
  end
end
