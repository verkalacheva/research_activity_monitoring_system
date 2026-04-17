# frozen_string_literal: true

module Achievements
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      Achievement.kept.includes(:achievement_field_answers, :achievement_type).order(created_at: :desc)
    end

    def row_serializer_class
      AchievementListSerializer
    end

    def default_limit
      20
    end
  end
end
