class AddDateToDevActivities < ActiveRecord::Migration[7.0]
  def change
    add_column :researcher_dev_activities, :date, :date
    add_column :team_dev_activities, :date, :date

    # Allow same researcher/team to have same activity on different dates
    add_index :researcher_dev_activities, [:researcher_id, :team_id, :dev_employee_activity_type_id, :date], unique: true, name: 'idx_res_dev_act_uniqueness'
    add_index :team_dev_activities, [:team_id, :dev_employee_activity_type_id, :date], unique: true, name: 'idx_team_dev_act_uniqueness'
  end
end
