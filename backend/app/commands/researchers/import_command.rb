require 'csv'

module Researchers
  class ImportCommand < BaseCommand
    def call(file_path:)
      begin
        content = File.read(file_path).force_encoding("UTF-8")
        unless content.valid_encoding?
          content = File.read(file_path).force_encoding("Windows-1251").encode("UTF-8")
        end
      rescue
        content = File.read(file_path)
      end

      # Handle BOM
      bom = "\xEF\xBB\xBF".force_encoding("UTF-8")
      content.sub!(bom, "") if content.start_with?(bom)
      content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

      separator = detect_separator(content)
      
      begin
        csv = CSV.parse(content, headers: true, col_sep: separator, quote_char: '"', liberal_parsing: true)
      rescue CSV::MalformedCSVError
        begin
          csv = CSV.parse(content, headers: true, col_sep: separator, quote_char: nil)
        rescue => e
          return Failure(type: :import_error, message: "CSV parsing failed: #{e.message.to_s.force_encoding('UTF-8')}")
        end
      end

      results = { success: 0, failure: 0, errors: [] }

      csv.each_with_index do |row, index|
        next if row.to_h.values.all?(&:blank?)

        result = process_row(row)
        if result.success?
          results[:success] += 1
        else
          results[:failure] += 1
          error_msg = if result.failure.is_a?(Hash)
                        result.failure[:errors] || result.failure[:message] || result.failure[:type]
                      else
                        result.failure.to_s
                      end
          results[:errors] << "Row #{index + 2}: #{error_msg}"
        end
      end

      Success(results)
    rescue => e
      msg = e.message.to_s.force_encoding('UTF-8')
      Rails.logger.error "Researchers import error: #{msg}\n#{e.backtrace.join("\n")}"
      Failure(type: :import_error, message: "Import failed: #{msg}")
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

    def process_row(row)
      transaction do
        full_name = row['ФИО']&.strip
        return Failure("ФИО обязательно") if full_name.blank?

        parts = full_name.split(/\s+/)
        surname = parts[0]
        name = parts[1] || "Неизвестно"
        second_name = parts[2..].join(' ') if parts.size > 2

        researcher = Researcher.find_or_initialize_by(surname: surname, name: name, second_name: second_name)
        
        researcher.assign_attributes(
          faculty: row['Факультет']&.strip,
          telegram: row['Телеграм']&.strip,
          email: row['Почта']&.strip,
          degree_level: row['Уровень образования']&.strip,
          course: row['Курс']&.to_i,
          subject_area: row['Направление']&.strip,
          employment_status: row['Трудоустройство']&.strip,
          isu_number: row['ИСУ']&.strip,
          github: row['Github']&.strip
        )

        unless researcher.save
          return Failure(errors: researcher.errors.full_messages)
        end

        # Handle Project/Team and Leader
        leader_name = row['Руководитель']&.strip
        if leader_name.present?
          # Search for leader in researchers
          l_parts = leader_name.split(/\s+/)
          l_surname = l_parts[0]
          l_rest = l_parts[1..].join(' ')
          
          # Search by surname and initials if provided
          query = Researcher.where("surname ILIKE ?", l_surname)
          
          if l_rest.present?
            if l_rest.include?('.')
              # Handle initials like "В.В." or "В. В."
              initials = l_rest.split('.').map { |s| s.gsub(/[^А-Яа-яA-Za-z]/, '') }.reject(&:empty?)
              query = query.where("name ILIKE ?", "#{initials[0]}%") if initials[0].present?
              query = query.where("second_name ILIKE ?", "#{initials[1]}%") if initials[1].present?
            else
              # Handle full names or space-separated initials
              parts = l_rest.split(/\s+/)
              query = query.where("name ILIKE ?", "#{parts[0]}%") if parts[0].present?
              query = query.where("second_name ILIKE ?", "#{parts[1]}%") if parts[1].present?
            end
          end

          leader = query.first
          
          if leader

            team = Team.find_by(leader_id: leader.id)
            
            
            if team.present?
                ResearchersTeam.find_or_create_by!(researcher: researcher, team: team)
            end
          end
        end

        Success(researcher)
      end
    end
  end
end
