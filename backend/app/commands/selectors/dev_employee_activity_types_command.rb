module Selectors
  class DevEmployeeActivityTypesCommand < BaseSelectorCommand
    private
    def model_class; DevEmployeeActivityType; end
    def serializer_class; SimpleEntitySerializer; end
    def apply_filters(scope, filters)
      filters[:query].present? ? scope.where("LOWER(title) LIKE ?", "%#{filters[:query].downcase}%") : scope
    end
  end
end
