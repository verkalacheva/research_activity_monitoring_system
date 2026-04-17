# frozen_string_literal: true

module Listings
  # Общая пагинация списков: scope + сериализатор + Selectors::ListPageInteractor.
  class PaginatedListCommand < BaseCommand
    def call(params)
      limit, offset = yield execute(:pagination_error) { parse_pagination(params) }
      scope = yield execute { list_scope }

      Selectors::ListPageInteractor.call(
        scope: scope,
        serializer_class: row_serializer_class,
        limit: limit,
        offset: offset,
        count_scope: total_count_scope(scope)
      )
    end

    protected

    def parse_pagination(params)
      lim = params[:limit].to_i
      off = params[:offset].to_i
      limit = lim.positive? ? lim : default_limit
      offset = off.negative? ? 0 : off
      [limit, offset]
    end

    def default_limit
      20
    end

    def list_scope
      raise NotImplementedError, "#{self.class} must implement #list_scope"
    end

    def row_serializer_class
      raise NotImplementedError, "#{self.class} must implement #row_serializer_class"
    end

    # Вернуть связь для подсчёта total, если нельзя вызывать .count на list_scope.
    def total_count_scope(_list_scope)
      nil
    end
  end
end
