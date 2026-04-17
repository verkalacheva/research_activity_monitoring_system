# frozen_string_literal: true

# Справочник: статус / результат / участие (id, title, points).
class AchievementCatalogRowSerializer < BaseSerializer
  def to_h
    object.as_json
  end
end
