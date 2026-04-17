# frozen_string_literal: true

module Teams
  class ListCommand < Listings::PaginatedListCommand
    protected

    def list_scope
      Team.includes(:researchers, :leader).order(:title)
    end

    def row_serializer_class
      TeamListSerializer
    end

    def default_limit
      20
    end
  end
end
