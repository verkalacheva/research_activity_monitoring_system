# frozen_string_literal: true

module AchievementStatuses
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      AchievementStatus.select(:id, :title, :points).order(:title)
    end

    def row_serializer_class
      AchievementCatalogRowSerializer
    end

    def default_limit
      100
    end

    def total_count_scope(_list_scope)
      AchievementStatus.all
    end
  end
end
