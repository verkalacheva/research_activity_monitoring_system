class AddDevAchievementsTables < ActiveRecord::Migration[7.0]
  def change
    # Add github field to researchers
    add_column :researchers, :github, :string

    # Create Dev Project Criteria reference table
    create_table :dev_project_criteria do |t|
      t.string :title, null: false
      t.decimal :points, precision: 10, scale: 2, default: 0.0
      t.timestamps
    end

    # Create Dev Employee Activity Types reference table
    create_table :dev_employee_activity_types do |t|
      t.string :title, null: false
      t.decimal :points, precision: 10, scale: 2, default: 0.0
      t.timestamps
    end

    # Link teams to criteria they meet
    create_table :team_dev_criteria do |t|
      t.references :team, null: false, foreign_key: true
      t.references :dev_project_criterion, null: false, foreign_key: { to_table: :dev_project_criteria }
      t.timestamps
    end

    # Track researcher activity in teams
    create_table :researcher_dev_activities do |t|
      t.references :researcher, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :dev_employee_activity_type, null: false, foreign_key: { to_table: :dev_employee_activity_types }, index: { name: 'idx_res_dev_act_on_type_id' }
      t.integer :count, default: 0
      t.timestamps
    end
  end
end
