# frozen_string_literal: true

module Researchers
  class ImportRowInteractor < BaseInteractor
    ORCID_EXACT_KEYS = %w[ORCID Orcid orcid ORCID_ID orcid_id orcid_Id OrcID].freeze
    ORCID_HEADER_NORMS = %w[orcid orcidid].freeze

    OPENALEX_EXACT_KEYS = %w[OpenAlex openalex OPENALEX openalex_id openalex_Id Openalex_ID open_alex_id Open_Alex_Id].freeze
    OPENALEX_HEADER_NORMS = %w[openalex openalexid].freeze

    GITHUB_EXACT_KEYS = %w[Github github GitHub github_username GithubUsername].freeze

    def call(row:)
      transaction do
        row = hash_from_csv_row(row)

        full_name = row['ФИО']&.strip
        return failure(:validation_error, 'ФИО обязательно') if full_name.blank?

        oid = normalize_orcid(row_fetch_identifier_cell(row, ORCID_EXACT_KEYS, ORCID_HEADER_NORMS))
        oax = normalize_openalex_id(row_fetch_identifier_cell(row, OPENALEX_EXACT_KEYS, OPENALEX_HEADER_NORMS))

        deg_raw = row['Уровень образования']&.strip
        if deg_raw.present? && Researcher::DEGREE_LEVELS.exclude?(deg_raw)
          allowed = Researcher::DEGREE_LEVELS.join(', ')
          return failure(:validation_error, "Уровень образования «#{deg_raw}» недопустим. Выберите одно из: #{allowed}")
        end

        parts = full_name.split(/\s+/)
        surname = parts[0]
        name = parts[1] || 'Неизвестно'
        second_name = parts[2..].join(' ') if parts.size > 2

        researcher = find_researcher(oid: oid, oax: oax, surname: surname, name: name,
                                       second_name: second_name)

        attrs = base_attributes(row).merge(
          deleted_at: nil,
          github: row_fetch_identifier_cell(row, GITHUB_EXACT_KEYS, [])&.strip,
          surname: surname,
          name: name,
          second_name: second_name.presence
        )
        attrs[:orcid_id] = oid.presence
        attrs[:openalex_id] = oax.presence
        researcher.assign_attributes(attrs)

        return failure(:database_error, researcher.errors.full_messages) unless researcher.save

        attach_to_leaders_team(row, researcher)

        success(researcher)
      end
    end

    private

    # По точному названию столбца, затем по «нормализованному» имени заголовка (Excel: orcid id, OrcId, open alex id …).
    def row_fetch_identifier_cell(row, exact_keys, fuzzy_header_norms)
      exact_keys.each do |key|
        v = row[key]
        next unless v.respond_to?(:to_s)

        s = v.to_s.strip
        next if s.blank?

        return s
      end

      row.each do |hdr, fld|
        next unless fld.respond_to?(:to_s)

        s = fld.to_s.strip
        next if s.blank?

        n = csv_header_normalized(hdr)
        return s if fuzzy_header_norms.include?(n)
      end

      nil
    end

    def csv_header_normalized(hdr)
      sanitize_csv_header_key(hdr.to_s).downcase.gsub(/[\s\-_]+/, '')
    end

    # Заголовки из Excel/UTF-8 могут начинаться с BOM (\uFEFF); String#strip его не убирает — тогда row['ФИО'] == nil.
    def sanitize_csv_header_key(key)
      key.to_s.delete_prefix("\uFEFF").strip
    end

    # CSV может прийти как CSV::Row с BOM/пробелами в заголовках; приводим к Hash с нормализованными ключами.
    def hash_from_csv_row(row)
      if row.is_a?(Hash)
        return row.transform_keys { |k| sanitize_csv_header_key(k) }
      end

      return {} unless row.respond_to?(:each)

      row.each_with_object({}) do |(hdr, fld), memo|
        next if hdr.nil?

        memo[sanitize_csv_header_key(hdr)] = fld
      end
    end

    def find_researcher(oid:, oax:, surname:, name:, second_name:)
      if oid.present?
        Researcher.find_or_initialize_by(orcid_id: oid)
      elsif oax.present?
        Researcher.find_or_initialize_by(openalex_id: oax)
      else
        Researcher.find_or_initialize_by(surname: surname, name: name, second_name: second_name)
      end
    end

    def base_attributes(row)
      {
        faculty: row['Факультет']&.strip,
        telegram: row['Телеграм']&.strip,
        email: row['Почта']&.strip,
        degree_level: row['Уровень образования']&.strip.presence,
        course: row['Курс']&.to_i,
        subject_area: row['Направление']&.strip,
        employment_status: row['Трудоустройство']&.strip,
        isu_number: row['ИСУ']&.strip
      }
    end

    # Допускаются URL с хвостовым "/", sandbox.orcid и токен вида XXXX…XXXX.
    def normalize_orcid(raw)
      s = raw.to_s.strip.delete_prefix("\uFEFF")
      return '' if s.blank?

      s = s.gsub(%r{\Ahttps?://sandbox\.orcid\.org/+}i, '')
      s = s.gsub(%r{\Ahttps?://(?:www\.)?orcid\.org/+}i, '')
      s = s.gsub(/[[:space:]]/, '').gsub(/[–—−]/u, '-') # нормализовать Unicode-дефисы
      s = s.gsub(%r{/+\z}, '')
      return s.downcase if s.match?(/\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/i)

      if (m = s.match(/\b(\d{4}-\d{4}-\d{4}-\d{3}[\dX])\b/i))
        return m[1].downcase
      end

      ''
    end

    # Канонический id вида A… (совместимо с grpc integration и REST OpenAlex).
    def normalize_openalex_id(raw)
      s = raw.to_s.strip.delete_prefix("\uFEFF")
      return '' if s.blank?

      s = s.gsub(%r{\Ahttps?://(?:www\.)?openalex\.org/+}i, '')
      s = s.gsub(%r{/+\z}, '')
      s.sub!(/\Aauthors\//i, '')

      if (m = s.match(/\A(A\d{9,})\z/i))
        return m[1].upcase
      end

      if (m = s.match(/\b(A\d{9,})\b/i))
        return m[1].upcase
      end

      ''
    end

    def attach_to_leaders_team(row, researcher)
      leader_name = row['Руководитель']&.strip
      return if leader_name.blank?

      l_parts = leader_name.split(/\s+/)
      l_surname = l_parts[0]
      l_rest = l_parts[1..].join(' ')

      query = Researcher.where('surname ILIKE ?', l_surname)

      if l_rest.present?
        if l_rest.include?('.')
          initials = l_rest.split('.').map { |s| s.gsub(/[^А-Яа-яA-Za-z]/, '') }.reject(&:empty?)
          query = query.where('name ILIKE ?', "#{initials[0]}%") if initials[0].present?
          query = query.where('second_name ILIKE ?', "#{initials[1]}%") if initials[1].present?
        else
          rest_parts = l_rest.split(/\s+/)
          query = query.where('name ILIKE ?', "#{rest_parts[0]}%") if rest_parts[0].present?
          query = query.where('second_name ILIKE ?', "#{rest_parts[1]}%") if rest_parts[1].present?
        end
      end

      leader = query.first
      return unless leader

      team = Team.find_by(leader_id: leader.id)
      ResearchersTeam.find_or_create_by!(researcher: researcher, team: team) if team.present?
    end
  end
end
