# frozen_string_literal: true

module Researchers
  # Одна строка CSV импорта исследователей (ФИО, факультет, привязка к команде руководителя).
  class ImportRowInteractor < BaseInteractor
    def call(row:)
      transaction do
        full_name = row['ФИО']&.strip
        return failure(:validation_error, 'ФИО обязательно') if full_name.blank?

        parts = full_name.split(/\s+/)
        surname = parts[0]
        name = parts[1] || 'Неизвестно'
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
          github: row['Github']&.strip,
          deleted_at: nil
        )

        return failure(:database_error, researcher.errors.full_messages) unless researcher.save

        attach_to_leaders_team(row, researcher)

        success(researcher)
      end
    end

    private

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
