# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_05_11_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "achievement_field_answers", force: :cascade do |t|
    t.bigint "achievement_field_id", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "achievement_id", null: false
    t.datetime "deleted_at"
    t.index ["achievement_field_id"], name: "index_achievement_field_answers_on_achievement_field_id"
    t.index ["achievement_id"], name: "index_achievement_field_answers_on_achievement_id"
    t.index ["deleted_at"], name: "index_achievement_field_answers_on_deleted_at"
  end

  create_table "achievement_fields", force: :cascade do |t|
    t.text "title"
    t.text "field_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_required", default: false
    t.bigint "achievement_type_id"
    t.jsonb "options", default: []
    t.datetime "deleted_at"
    t.index ["achievement_type_id"], name: "index_achievement_fields_on_achievement_type_id"
    t.index ["deleted_at"], name: "index_achievement_fields_on_deleted_at"
  end

  create_table "achievement_participations", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_achievement_participations_on_deleted_at"
  end

  create_table "achievement_results", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_achievement_results_on_deleted_at"
  end

  create_table "achievement_statuses", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_achievement_statuses_on_deleted_at"
  end

  create_table "achievement_types", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_name"
    t.datetime "deleted_at"
    t.text "description"
    t.index ["deleted_at"], name: "index_achievement_types_on_deleted_at"
  end

  create_table "achievements", force: :cascade do |t|
    t.bigint "achievement_type_id", null: false
    t.bigint "achievement_status_id", null: false
    t.bigint "achievement_result_id", null: false
    t.bigint "achievement_participation_id", null: false
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "submission_date"
    t.datetime "deleted_at"
    t.index ["achievement_participation_id"], name: "index_achievements_on_achievement_participation_id"
    t.index ["achievement_result_id"], name: "index_achievements_on_achievement_result_id"
    t.index ["achievement_status_id"], name: "index_achievements_on_achievement_status_id"
    t.index ["achievement_type_id"], name: "index_achievements_on_achievement_type_id"
    t.index ["deleted_at"], name: "index_achievements_on_deleted_at"
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "dev_employee_activity_types", force: :cascade do |t|
    t.string "title", null: false
    t.decimal "points", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "check_key"
    t.index ["check_key"], name: "index_dev_employee_activity_types_on_check_key", unique: true, where: "(check_key IS NOT NULL)"
  end

  create_table "dev_project_criteria", force: :cascade do |t|
    t.string "title", null: false
    t.decimal "points", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "check_key"
    t.index ["check_key"], name: "index_dev_project_criteria_on_check_key", unique: true, where: "(check_key IS NOT NULL)"
  end

  create_table "researcher_achievements", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "achievement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_researcher_achievements_on_achievement_id"
    t.index ["researcher_id"], name: "index_researcher_achievements_on_researcher_id"
  end

  create_table "researcher_activity_details", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "team_id"
    t.string "activity_type", null: false
    t.string "external_id", null: false
    t.text "title"
    t.string "repository"
    t.string "url"
    t.date "date"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id", "activity_type", "researcher_id"], name: "idx_activity_details_uniqueness", unique: true
    t.index ["researcher_id"], name: "index_researcher_activity_details_on_researcher_id"
    t.index ["team_id"], name: "index_researcher_activity_details_on_team_id"
  end

  create_table "researcher_dev_activities", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "team_id"
    t.bigint "dev_employee_activity_type_id", null: false
    t.integer "count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["dev_employee_activity_type_id"], name: "idx_res_dev_act_on_type_id"
    t.index ["researcher_id", "dev_employee_activity_type_id", "date"], name: "idx_res_dev_act_uniqueness_no_team", unique: true, where: "(team_id IS NULL)"
    t.index ["researcher_id", "team_id", "dev_employee_activity_type_id", "date"], name: "idx_res_dev_act_uniqueness_with_team", unique: true, where: "(team_id IS NOT NULL)"
    t.index ["researcher_id"], name: "index_researcher_dev_activities_on_researcher_id"
    t.index ["team_id"], name: "index_researcher_dev_activities_on_team_id"
  end

  create_table "researchers", force: :cascade do |t|
    t.text "name"
    t.text "surname"
    t.text "second_name"
    t.text "degree_level"
    t.integer "course"
    t.text "subject_area"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "email"
    t.text "telegram"
    t.text "isu_number"
    t.text "faculty"
    t.text "employment_status"
    t.datetime "deleted_at"
    t.text "orcid_id"
    t.text "openalex_id"
    t.string "github"
    t.index ["deleted_at"], name: "index_researchers_on_deleted_at"
    t.index ["openalex_id"], name: "index_researchers_on_openalex_id"
    t.index ["orcid_id"], name: "index_researchers_on_orcid_id", unique: true
  end

  create_table "researchers_teams", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["researcher_id"], name: "index_researchers_teams_on_researcher_id"
    t.index ["team_id"], name: "index_researchers_teams_on_team_id"
  end

  create_table "team_dev_activities", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "dev_employee_activity_type_id", null: false
    t.integer "count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["dev_employee_activity_type_id"], name: "index_team_dev_activities_on_dev_employee_activity_type_id"
    t.index ["team_id", "dev_employee_activity_type_id", "date"], name: "idx_team_dev_act_uniqueness", unique: true
    t.index ["team_id"], name: "index_team_dev_activities_on_team_id"
  end

  create_table "team_dev_criteria", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "dev_project_criterion_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dev_project_criterion_id"], name: "index_team_dev_criteria_on_dev_project_criterion_id"
    t.index ["team_id"], name: "index_team_dev_criteria_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.text "title"
    t.bigint "leader_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "github_repo_url"
    t.index ["deleted_at"], name: "index_teams_on_deleted_at"
    t.index ["leader_id"], name: "index_teams_on_leader_id"
  end

  add_foreign_key "achievement_field_answers", "achievement_fields"
  add_foreign_key "achievement_field_answers", "achievements"
  add_foreign_key "achievement_fields", "achievement_types"
  add_foreign_key "achievements", "achievement_participations"
  add_foreign_key "achievements", "achievement_results"
  add_foreign_key "achievements", "achievement_statuses"
  add_foreign_key "achievements", "achievement_types"
  add_foreign_key "researcher_achievements", "achievements"
  add_foreign_key "researcher_achievements", "researchers"
  add_foreign_key "researcher_activity_details", "researchers"
  add_foreign_key "researcher_activity_details", "teams"
  add_foreign_key "researcher_dev_activities", "dev_employee_activity_types"
  add_foreign_key "researcher_dev_activities", "researchers"
  add_foreign_key "researcher_dev_activities", "teams"
  add_foreign_key "researchers_teams", "researchers"
  add_foreign_key "researchers_teams", "teams"
  add_foreign_key "team_dev_activities", "dev_employee_activity_types"
  add_foreign_key "team_dev_activities", "teams"
  add_foreign_key "team_dev_criteria", "dev_project_criteria"
  add_foreign_key "team_dev_criteria", "teams"
  add_foreign_key "teams", "researchers", column: "leader_id"
end
