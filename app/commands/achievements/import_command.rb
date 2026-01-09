require 'csv'

module Achievements
  class ImportCommand < BaseCommand
    def call(file_path:)
      # Detect encoding or assume UTF-8/Windows-1251
      begin
        content = File.read(file_path).force_encoding("UTF-8")
        unless content.valid_encoding?
          content = File.read(file_path).force_encoding("Windows-1251").encode("UTF-8")
        end
      rescue
        content = File.read(file_path)
      end
      
      # Handle BOM if present
      bom = "\xEF\xBB\xBF".force_encoding("UTF-8")
      content.sub!(bom, "") if content.start_with?(bom)
      
      content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      
      separator = detect_separator(content)
      
      begin
        csv = CSV.parse(content, headers: true, col_sep: separator, quote_char: '"', liberal_parsing: true)
      rescue CSV::MalformedCSVError
        # Try without quote char if it fails
        begin
          csv = CSV.parse(content, headers: true, col_sep: separator, quote_char: nil)
        rescue => e
          return Failure(type: :import_error, message: "CSV parsing failed: #{e.message}")
        end
      end
      
      results = { success: 0, failure: 0, errors: [] }

      csv.each_with_index do |row, index|
        # Skip empty rows
        next if row.to_h.values.all?(&:blank?)

        # Convert row to a list of pairs to handle duplicate header names
        row_pairs = row.to_a 
        
        result = process_row(row_pairs)
        if result.success?
          results[:success] += 1
        else
          results[:failure] += 1
          error_msg = case result.failure
                      when Hash then result.failure[:errors] || result.failure[:message] || result.failure[:type]
                      else result.failure.to_s
                      end
          results[:errors] << "Row #{index + 2}: #{error_msg}"
        end
      end

      Success(results)
    rescue => e
      Rails.logger.error "Import error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      Failure(type: :import_error, message: "Import failed: #{e.message}")
    end

    private

    def detect_separator(content)
      first_line = content.each_line.first
      return ',' if first_line.blank?
      
      if first_line.include?(';')
        ';'
      elsif first_line.include?("\t")
        "\t"
      else
        ','
      end
    end

    def process_row(row_pairs)
      transaction do
        full_name = find_value(row_pairs, 'Ваше ФИО')
        researcher = find_or_create_researcher(full_name)
        return Failure("Researcher '#{full_name}' not found or created") unless researcher

        type_title = find_value(row_pairs, 'Тип достижения')
        return Failure("Achievement type is empty") if type_title.blank?

        type = AchievementType.find_or_create_by!(title: type_title) do |t|
          t.points = 1.0
        end

        # Common fields
        status_title = find_value(row_pairs, ['Статус мероприятия', 'Статус'])
        result_title = find_value(row_pairs, 'Результат')
        quartile = find_value(row_pairs, 'Квартиль')
        participation_title = find_value(row_pairs, 'Участие')

        status = find_or_create_status(status_title)
        result_obj = find_or_create_result(result_title, quartile)
        participation = find_or_create_participation(participation_title)

        submission_date = nil
        timestamp = find_value(row_pairs, 'Timestamp')
        if timestamp.present?
          begin
            # Google Sheets timestamp: "2/22/2025 15:27:34"
            if timestamp.include?('/')
              submission_date = DateTime.strptime(timestamp, '%m/%d/%Y %H:%M:%S')
            else
              submission_date = DateTime.parse(timestamp)
            end
          rescue => e
            Rails.logger.warn "Failed to parse timestamp '#{timestamp}': #{e.message}"
          end
        end

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

    def find_value(row_pairs, keys)
      keys = Array(keys)
      # Find the first non-blank value among all columns matching any of the keys
      row_pairs.each do |key, value|
        return value.strip if keys.include?(key) && value.present?
      end
      nil
    end

    def find_or_create_researcher(full_name)
      return nil if full_name.blank?
      
      parts = full_name.strip.split(/\s+/)
      surname = parts[0]
      name = parts[1] || "Неизвестно"
      second_name = parts[2..].join(' ') if parts.size > 2

      Researcher.find_or_create_by!(surname: surname, name: name, second_name: second_name)
    end

    def find_or_create_status(title)
      title = title.to_s.strip
      status = AchievementStatus.find_by("title ILIKE ?", "%#{title}%") if title.present?
      status || AchievementStatus.find_or_create_by!(title: title.presence || 'Не указано') do |s|
        s.points = 1.0
      end
    end

    def find_or_create_result(title, quartile = nil)
      title = title.to_s.strip
      quartile = quartile.to_s.strip
      
      # Priority: quartile (Q1, Q2, etc.), then result title
      search_term = quartile.presence || title
      
      res = AchievementResult.find_by("title ILIKE ?", "%#{search_term}%") if search_term.present?
      res || AchievementResult.find_or_create_by!(title: search_term.presence || 'Не указано') do |r|
        r.points = 1.0
      end
    end

    def find_or_create_participation(title)
      title = title.to_s.strip
      part = AchievementParticipation.find_by("title ILIKE ?", "%#{title}%") if title.present?
      part || AchievementParticipation.find_or_create_by!(title: title.presence || 'Не указано') do |p|
        p.points = 1.0
      end
    end

    def build_answers(type, row_pairs)
      type.achievement_fields.map do |field|
        value = find_value(row_pairs, field.title)
        next if value.blank?

        # Format dates from Google Sheets (M/D/YYYY or M/D/YYYY H:MM:SS) to ISO 8601
        if field.field_type == 'date'
          begin
            # Google Sheets often exports dates with slashes and sometimes with time
            if value.include?('/')
              # Remove time part if present (e.g., "2/22/2025 15:27:34" -> "2/22/2025")
              date_part = value.split(' ').first
              
              # Parse as M/D/YYYY (standard Google Sheets export format)
              parsed_date = Date.strptime(date_part, '%m/%d/%Y')
              value = parsed_date.iso8601
            end
          rescue => e
            Rails.logger.warn "Failed to parse Google Sheets date '#{value}' for field '#{field.title}': #{e.message}"
          end
        end

        { achievement_field_id: field.id, value: value.to_s }
      end.compact
    end
  end
end
