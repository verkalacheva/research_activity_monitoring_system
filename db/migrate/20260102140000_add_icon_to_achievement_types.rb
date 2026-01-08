class AddIconToAchievementTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :achievement_types, :icon_name, :string
  end
end


