module Researchers
  class ListCommand < BaseCommand
    def call(params)
      limit, offset = yield execute(:pagination_error) { parse_pagination(params) }
      scope = yield execute { build_scope }
      total = yield execute { count_total(scope) }
      items = yield execute { fetch_items(scope, limit, offset) }
      
      success({
        items: format_items(items),
        pagination: {
          total: total,
          limit: limit,
          offset: offset
        }
      })
    end

    private

    def parse_pagination(params)
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      offset = params[:offset].to_i >= 0 ? params[:offset].to_i : 0
      [limit, offset]
    end

    def build_scope
      # Optimized scope with subquery for is_leader to avoid N+1 queries
      Researcher.kept.select(
        :id, :surname, :name, :second_name, :degree_level, :subject_area,
        "(EXISTS (SELECT 1 FROM teams WHERE teams.leader_id = researchers.id)) AS is_leader"
      ).order(:surname, :name, :second_name)
    end

    def count_total(scope)
      Researcher.kept.count
    end

    def fetch_items(scope, limit, offset)
      scope.limit(limit).offset(offset)
    end

    def format_items(items)
      items.map do |r|
        {
          id: r.id,
          surname: r.surname,
          name: r.name,
          second_name: r.second_name,
          degree_level: r.degree_level,
          subject_area: r.subject_area,
          is_leader: r.is_leader
        }
      end
    end
  end
end

