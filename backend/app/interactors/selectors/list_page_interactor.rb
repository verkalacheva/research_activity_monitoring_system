# frozen_string_literal: true

module Selectors
  # Пагинация + сериализация элементов списка (селекторы API).
  class ListPageInteractor < BaseInteractor
    # count_scope — отдельная связь для COUNT, если у scope есть includes / custom select и scope.count неверен.
    def call(scope:, serializer_class:, limit:, offset:, count_scope: nil)
      execute do
        total = (count_scope || scope).count
        items = scope.limit(limit).offset(offset)
        {
          items: items.map { |item| serializer_class.new(item).to_h },
          pagination: {
            total: total,
            limit: limit,
            offset: offset
          }
        }
      end
    end
  end
end
