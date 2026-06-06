# frozen_string_literal: true

module Teams
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      Team.kept.for_current_admin.includes(:researchers, :leader).order(:title)
    end

    def row_serializer_class
      TeamListSerializer
    end

    def default_limit
      20
    end

    def total_count_scope(_list_scope)
      Team.kept.for_current_admin
    end
  end
end
