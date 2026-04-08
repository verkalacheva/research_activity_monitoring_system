class AddDeletedAtToMainTables < ActiveRecord::Migration[7.0]
  def change
    tables = [
      :researchers,
      :achievements,
      :teams,
      :achievement_types,
      :achievement_statuses,
      :achievement_results,
      :achievement_participations,
      :achievement_fields,
      :achievement_field_answers
    ]

    tables.each do |table_name|
      add_column table_name, :deleted_at, :datetime
      add_index table_name, :deleted_at
    end
  end
end






