# frozen_string_literal: true

module Selectors
  class BaseSelectorCommand < ::BaseCommand
    def call(params)
      limit, offset = yield execute(:pagination_error) { parse_pagination(params) }
      scope = yield execute { build_scope(params) }

      Selectors::ListPageInteractor.call(
        scope: scope,
        serializer_class: serializer_class,
        limit: limit,
        offset: offset
      )
    end

    private

    def parse_pagination(params)
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 10
      offset = params[:offset].to_i >= 0 ? params[:offset].to_i : 0
      [limit, offset]
    end

    def build_scope(params)
      scope = model_class.kept
      filters = (params[:filters] || {}).merge(params)
      scope = apply_filters(scope, filters)
      apply_default_sort(scope)
    end

    def apply_default_sort(scope)
      if model_class.column_names.include?('title')
        scope.order(:title)
      elsif model_class.column_names.include?('surname')
        scope.order(:surname, :name, :second_name)
      else
        scope.order(:id)
      end
    end

    def apply_filters(scope, filters)
      scope
    end

    def model_class
      raise NotImplementedError
    end

    def serializer_class
      raise NotImplementedError
    end
  end
end
