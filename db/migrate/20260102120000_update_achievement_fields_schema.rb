class UpdateAchievementFieldsSchema < ActiveRecord::Migration[7.0]
  def change
    add_column :achievement_fields, :is_required, :boolean, default: false
    add_reference :achievement_fields, :achievement_type, foreign_key: true

    remove_reference :achievements, :achievement_field_answer, foreign_key: true
    add_reference :achievement_field_answers, :achievement, null: false, foreign_key: true

    drop_table :achievement_type_fields do |t|
      t.bigint :achievement_type_id, null: false
      t.bigint :achievement_field_id, null: false
      t.timestamps
    end
  end
end

