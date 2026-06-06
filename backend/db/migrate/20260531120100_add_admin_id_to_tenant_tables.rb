# frozen_string_literal: true

class AddAdminIdToTenantTables < ActiveRecord::Migration[7.0]
  TENANT_TABLES = %i[
    researchers
    teams
    achievement_types
    achievement_statuses
    achievement_results
    achievement_participations
    dev_employee_activity_types
    dev_project_criteria
    app_settings
  ].freeze

  def change
    TENANT_TABLES.each do |table|
      add_reference table, :admin, foreign_key: { to_table: :users }, index: true
    end
  end
end
