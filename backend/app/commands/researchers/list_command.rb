# frozen_string_literal: true

module Researchers
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      Researcher.kept.select(
        :id, :surname, :name, :second_name, :degree_level, :subject_area,
        '(EXISTS (SELECT 1 FROM teams WHERE teams.leader_id = researchers.id)) AS is_leader'
      ).order(:surname, :name, :second_name)
    end

    def row_serializer_class
      ResearcherListRowSerializer
    end

    def default_limit
      20
    end

    def total_count_scope(_list_scope)
      Researcher.kept
    end
  end
end
