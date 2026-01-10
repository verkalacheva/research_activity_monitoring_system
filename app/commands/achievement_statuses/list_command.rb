module AchievementStatuses
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
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 100
      offset = params[:offset].to_i >= 0 ? params[:offset].to_i : 0
      [limit, offset]
    end

    def build_scope
      AchievementStatus.order(:title)
    end

    def count_total(scope)
      AchievementStatus.count
    end

    def fetch_items(scope, limit, offset)
      scope.select(:id, :title, :points).limit(limit).offset(offset)
    end

    def format_items(items)
      items.as_json
    end
  end
end

