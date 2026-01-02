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

ActiveRecord::Schema[7.0].define(version: 2026_01_02_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "achievement_field_answers", force: :cascade do |t|
    t.bigint "achievement_field_id", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_field_id"], name: "index_achievement_field_answers_on_achievement_field_id"
  end

  create_table "achievement_fields", force: :cascade do |t|
    t.text "title"
    t.text "field_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_participations", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_results", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_statuses", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_type_fields", force: :cascade do |t|
    t.bigint "achievement_type_id", null: false
    t.bigint "achievement_field_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_field_id"], name: "index_achievement_type_fields_on_achievement_field_id"
    t.index ["achievement_type_id"], name: "index_achievement_type_fields_on_achievement_type_id"
  end

  create_table "achievement_types", force: :cascade do |t|
    t.text "title"
    t.float "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievements", force: :cascade do |t|
    t.bigint "achievement_type_id", null: false
    t.bigint "achievement_status_id", null: false
    t.bigint "achievement_result_id", null: false
    t.bigint "achievement_participation_id", null: false
    t.float "points"
    t.bigint "achievement_field_answer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_field_answer_id"], name: "index_achievements_on_achievement_field_answer_id"
    t.index ["achievement_participation_id"], name: "index_achievements_on_achievement_participation_id"
    t.index ["achievement_result_id"], name: "index_achievements_on_achievement_result_id"
    t.index ["achievement_status_id"], name: "index_achievements_on_achievement_status_id"
    t.index ["achievement_type_id"], name: "index_achievements_on_achievement_type_id"
  end

  create_table "researcher_achievements", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "achievement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_researcher_achievements_on_achievement_id"
    t.index ["researcher_id"], name: "index_researcher_achievements_on_researcher_id"
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
  end

  create_table "researchers_teams", force: :cascade do |t|
    t.bigint "researcher_id", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["researcher_id"], name: "index_researchers_teams_on_researcher_id"
    t.index ["team_id"], name: "index_researchers_teams_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.text "title"
    t.bigint "leader_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["leader_id"], name: "index_teams_on_leader_id"
  end

  add_foreign_key "achievement_field_answers", "achievement_fields"
  add_foreign_key "achievement_type_fields", "achievement_fields"
  add_foreign_key "achievement_type_fields", "achievement_types"
  add_foreign_key "achievements", "achievement_field_answers"
  add_foreign_key "achievements", "achievement_participations"
  add_foreign_key "achievements", "achievement_results"
  add_foreign_key "achievements", "achievement_statuses"
  add_foreign_key "achievements", "achievement_types"
  add_foreign_key "researcher_achievements", "achievements"
  add_foreign_key "researcher_achievements", "researchers"
  add_foreign_key "researchers_teams", "researchers"
  add_foreign_key "researchers_teams", "teams"
  add_foreign_key "teams", "researchers", column: "leader_id"
end
