module Selectors
  class TeamsCommand < BaseSelectorCommand
    private

    def model_class
      Team
    end

    def serializer_class
      TeamSerializer
    end

    def apply_filters(scope, filters)
      if filters[:query].present?
        q = "%#{filters[:query].downcase}%"
        scope = scope.where("LOWER(title) LIKE ?", q)
      end

      scope
    end
  end
end



