# frozen_string_literal: true

# Строка списка исследователей (в т.ч. виртуальный is_leader из SELECT).
class ResearcherListRowSerializer < BaseSerializer
  def to_h
    {
      id: object.id,
      surname: object.surname,
      name: object.name,
      second_name: object.second_name,
      degree_level: object.degree_level,
      subject_area: object.subject_area,
      orcid_id: object.try(:orcid_id),
      openalex_id: object.try(:openalex_id),
      is_leader: ActiveModel::Type::Boolean.new.cast(object.try(:is_leader))
    }
  end
end
