# frozen_string_literal: true

module Achievements
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      Achievement.kept
             .joins(:achievement_type)
             .where(achievement_types: { admin_id: Current.admin_id })
             .includes(:achievement_field_answers, :achievement_type)
             .order(created_at: :desc)
    end

    def row_serializer_class
      AchievementListSerializer
    end

    def default_limit
      20
    end
  end
end
