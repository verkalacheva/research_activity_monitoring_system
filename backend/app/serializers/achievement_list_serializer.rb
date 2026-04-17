# frozen_string_literal: true

# Элемент списка достижений (как раньше as_json с вложениями).
class AchievementListSerializer < BaseSerializer
  def to_h
    object.as_json(include: %i[achievement_field_answers achievement_type])
  end
end
