# frozen_string_literal: true

class BackfillAdminIdAndConstraints < ActiveRecord::Migration[7.0]
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

  def up
    admin_id = create_default_admin!

    TENANT_TABLES.each do |table|
      execute <<~SQL.squish
        UPDATE #{table} SET admin_id = #{admin_id} WHERE admin_id IS NULL
      SQL

      null_count = select_value("SELECT COUNT(*) FROM #{table} WHERE admin_id IS NULL").to_i
      raise "Backfill failed for #{table}: #{null_count} rows without admin_id" if null_count.positive?

      change_column_null table, :admin_id, false
    end

    replace_unique_indexes
  end

  def down
    revert_unique_indexes

    TENANT_TABLES.each do |table|
      change_column_null table, :admin_id, true
      execute "UPDATE #{table} SET admin_id = NULL"
    end

    email = ENV.fetch('DEFAULT_ADMIN_EMAIL', 'admin@example.com').downcase.strip
    execute <<~SQL.squish
      DELETE FROM users WHERE email = #{quote(email)} AND role = 'admin' AND admin_id IS NULL
    SQL
  end

  private

  def create_default_admin!
    email = ENV.fetch('DEFAULT_ADMIN_EMAIL', 'admin@example.com').downcase.strip
    password = ENV.fetch('DEFAULT_ADMIN_PASSWORD', 'password123456')
    full_name = ENV.fetch('DEFAULT_ADMIN_FULL_NAME', 'Администратор')
    digest = BCrypt::Password.create(password)
    now = connection.quote(Time.current.utc)

    existing = select_value(<<~SQL.squish)
      SELECT id FROM users WHERE email = #{quote(email)} AND role = 'admin' AND admin_id IS NULL LIMIT 1
    SQL
    return existing.to_i if existing.present?

    execute <<~SQL.squish
      INSERT INTO users (email, password_digest, role, full_name, is_active, created_at, updated_at)
      VALUES (#{quote(email)}, #{quote(digest.to_s)}, 'admin', #{quote(full_name)}, TRUE, #{now}, #{now})
    SQL

    select_value("SELECT id FROM users WHERE email = #{quote(email)} LIMIT 1").to_i
  end

  def replace_unique_indexes
    remove_index :researchers, name: 'index_researchers_on_orcid_id', if_exists: true
    remove_index :researchers, name: 'index_researchers_on_openalex_id', if_exists: true
    remove_index :app_settings, name: 'index_app_settings_on_key', if_exists: true
    remove_index :dev_employee_activity_types, name: 'index_dev_employee_activity_types_on_check_key', if_exists: true
    remove_index :dev_project_criteria, name: 'index_dev_project_criteria_on_check_key', if_exists: true

    add_index :researchers, %i[admin_id orcid_id],
              unique: true,
              where: 'orcid_id IS NOT NULL',
              name: 'index_researchers_on_admin_id_and_orcid_id'
    add_index :researchers, %i[admin_id openalex_id],
              unique: true,
              where: 'openalex_id IS NOT NULL',
              name: 'index_researchers_on_admin_id_and_openalex_id'
    add_index :app_settings, %i[admin_id key],
              unique: true,
              name: 'index_app_settings_on_admin_id_and_key'
    add_index :dev_employee_activity_types, %i[admin_id check_key],
              unique: true,
              where: 'check_key IS NOT NULL',
              name: 'index_dev_employee_activity_types_on_admin_id_and_check_key'
    add_index :dev_project_criteria, %i[admin_id check_key],
              unique: true,
              where: 'check_key IS NOT NULL',
              name: 'index_dev_project_criteria_on_admin_id_and_check_key'
  end

  def revert_unique_indexes
    remove_index :researchers, name: 'index_researchers_on_admin_id_and_orcid_id', if_exists: true
    remove_index :researchers, name: 'index_researchers_on_admin_id_and_openalex_id', if_exists: true
    remove_index :app_settings, name: 'index_app_settings_on_admin_id_and_key', if_exists: true
    remove_index :dev_employee_activity_types, name: 'index_dev_employee_activity_types_on_admin_id_and_check_key', if_exists: true
    remove_index :dev_project_criteria, name: 'index_dev_project_criteria_on_admin_id_and_check_key', if_exists: true

    add_index :researchers, :orcid_id, unique: true, name: 'index_researchers_on_orcid_id', if_not_exists: true
    add_index :researchers, :openalex_id, name: 'index_researchers_on_openalex_id', if_not_exists: true
    add_index :app_settings, :key, unique: true, name: 'index_app_settings_on_key', if_not_exists: true
    add_index :dev_employee_activity_types, :check_key,
              unique: true,
              where: 'check_key IS NOT NULL',
              name: 'index_dev_employee_activity_types_on_check_key',
              if_not_exists: true
    add_index :dev_project_criteria, :check_key,
              unique: true,
              where: 'check_key IS NOT NULL',
              name: 'index_dev_project_criteria_on_check_key',
              if_not_exists: true
  end
end
