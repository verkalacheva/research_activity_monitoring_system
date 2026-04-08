# frozen_string_literal: true

class AddDescriptionToAchievementTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :achievement_types, :description, :text
  end
end
