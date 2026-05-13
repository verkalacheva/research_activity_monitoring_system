# frozen_string_literal: true

class AllowNullTeamIdOnResearcherDevTables < ActiveRecord::Migration[7.0]
  def up
    remove_index :researcher_dev_activities, name: 'idx_res_dev_act_uniqueness'

    change_column_null :researcher_dev_activities, :team_id, true
    change_column_null :researcher_activity_details, :team_id, true

    add_index :researcher_dev_activities,
              %i[researcher_id team_id dev_employee_activity_type_id date],
              unique: true,
              where: 'team_id IS NOT NULL',
              name: 'idx_res_dev_act_uniqueness_with_team'

    add_index :researcher_dev_activities,
              %i[researcher_id dev_employee_activity_type_id date],
              unique: true,
              where: 'team_id IS NULL',
              name: 'idx_res_dev_act_uniqueness_no_team'
  end

  def down
    execute 'DELETE FROM researcher_dev_activities WHERE team_id IS NULL'
    execute 'DELETE FROM researcher_activity_details WHERE team_id IS NULL'

    remove_index :researcher_dev_activities, name: 'idx_res_dev_act_uniqueness_with_team'
    remove_index :researcher_dev_activities, name: 'idx_res_dev_act_uniqueness_no_team'

    change_column_null :researcher_dev_activities, :team_id, false
    change_column_null :researcher_activity_details, :team_id, false

    add_index :researcher_dev_activities,
              %i[researcher_id team_id dev_employee_activity_type_id date],
              unique: true,
              name: 'idx_res_dev_act_uniqueness'
  end
end
