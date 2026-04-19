# frozen_string_literal: true

module Achievements
  class ImportRowInteractor < BaseInteractor
    def call(row_pairs:)
      transaction do
        full_name = find_value(row_pairs, 'Ваше ФИО')
        researcher = find_or_create_researcher(full_name)
        return failure(:validation_error, "Researcher '#{full_name}' not found or created") unless researcher

        type_title = find_value(row_pairs, 'Тип достижения')
        return failure(:validation_error, 'Achievement type is empty') if type_title.blank?

        type = AchievementType.find_or_create_by!(title: type_title) do |t|
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

        achievement_params = {
          achievement_type_id: type.id,
          achievement_status_id: status.id,
          achievement_result_id: result_obj.id,
          achievement_participation_id: participation.id,
          researcher_ids: [researcher.id],
          submission_date: submission_date&.iso8601,
          achievement_field_answers_attributes: build_answers(type, row_pairs)
        }

        Achievements::CreateCommand.call(achievement_params)
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

    def find_or_create_researcher(full_name)
      return nil if full_name.blank?

      parts = full_name.strip.split(/\s+/)
      surname = parts[0]
      name = parts[1] || 'Неизвестно'
      second_name = parts[2..].join(' ') if parts.size > 2

      researcher = Researcher.find_or_create_by!(surname: surname, name: name, second_name: second_name)
      researcher.restore if researcher.deleted?
      researcher
    end

    def find_or_create_status(title)
      title = title.to_s.strip
      status = AchievementStatus.find_by('title ILIKE ?', "%#{title}%") if title.present?
      status || AchievementStatus.find_or_create_by!(title: title.presence || 'Не указано') do |s|
        s.points = 1.0
      end
    end

    def find_or_create_result(title, quartile = nil)
      title = title.to_s.strip
      quartile = quartile.to_s.strip

      search_term = quartile.presence || title

      res = AchievementResult.find_by('title ILIKE ?', "%#{search_term}%") if search_term.present?
      res || AchievementResult.find_or_create_by!(title: search_term.presence || 'Не указано') do |r|
        r.points = 1.0
      end
    end

    def find_or_create_participation(title)
      title = title.to_s.strip
      part = AchievementParticipation.find_by('title ILIKE ?', "%#{title}%") if title.present?
      part || AchievementParticipation.find_or_create_by!(title: title.presence || 'Не указано') do |p|
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
