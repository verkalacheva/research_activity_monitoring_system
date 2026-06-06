# frozen_string_literal: true

module AchievementTypes
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      AchievementType.kept.for_current_admin.includes(:achievement_fields).order(:title)
    end

    def row_serializer_class
      AchievementTypeListSerializer
    end

    def default_limit
      100
    end

    def total_count_scope(_list_scope)
      AchievementType.kept.for_current_admin
    end
  end
end
