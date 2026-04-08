class AddOptionsToAchievementFields < ActiveRecord::Migration[7.0]
  def change
    add_column :achievement_fields, :options, :jsonb, default: []
  end
end

