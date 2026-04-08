class CreateTeamDevActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :team_dev_activities do |t|
      t.references :team, null: false, foreign_key: true
      t.references :dev_employee_activity_type, null: false, foreign_key: true
      t.integer :count, default: 0

      t.timestamps
    end
  end
end
