# frozen_string_literal: true

# Тип достижения в списке с полями формы.
class AchievementTypeListSerializer < BaseSerializer
  def to_h
    object.as_json(include: :achievement_fields)
  end
end
