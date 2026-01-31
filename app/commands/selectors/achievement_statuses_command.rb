module Selectors
  class AchievementStatusesCommand < BaseSelectorCommand
    private
    def model_class; AchievementStatus; end
    def serializer_class; SimpleEntitySerializer; end
    def apply_filters(scope, filters)
      filters[:query].present? ? scope.where("LOWER(title) LIKE ?", "%#{filters[:query].downcase}%") : scope
    end
  end
end



