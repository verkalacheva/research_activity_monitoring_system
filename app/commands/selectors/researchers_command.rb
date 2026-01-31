module Selectors
  class ResearchersCommand < BaseSelectorCommand
    private

    def model_class
      Researcher
    end

    def serializer_class
      ResearcherSerializer
    end

    def apply_filters(scope, filters)
      if filters[:query].present?
        q = "%#{filters[:query].downcase}%"
        scope = scope.where(
          "LOWER(surname) LIKE :q OR LOWER(name) LIKE :q OR LOWER(second_name) LIKE :q OR LOWER(email) LIKE :q",
          q: q
        )
      end

      if filters[:degree_level].present?
        scope = scope.where(degree_level: filters[:degree_level])
      end

      scope
    end
  end
end



