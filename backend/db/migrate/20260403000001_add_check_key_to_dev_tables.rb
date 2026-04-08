class AddCheckKeyToDevTables < ActiveRecord::Migration[7.0]
  def change
    add_column :dev_project_criteria, :check_key, :string
    add_column :dev_employee_activity_types, :check_key, :string

    add_index :dev_project_criteria, :check_key, unique: true, where: "check_key IS NOT NULL"
    add_index :dev_employee_activity_types, :check_key, unique: true, where: "check_key IS NOT NULL"
  end
end
