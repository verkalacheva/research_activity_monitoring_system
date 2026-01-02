class CreateInitialSchema < ActiveRecord::Migration[7.0]
  def change
    create_table :researchers do |t|
      t.text :name
      t.text :surname
      t.text :second_name
      t.text :degree_level
      t.integer :course
      t.text :subject_area

      t.timestamps
    end

    create_table :teams do |t|
      t.text :title
      t.references :leader, foreign_key: { to_table: :researchers }

      t.timestamps
    end

    create_table :researchers_teams do |t|
      t.references :researcher, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end

    create_table :achievement_types do |t|
      t.text :title
      t.float :points

      t.timestamps
    end

    create_table :achievement_statuses do |t|
      t.text :title
      t.float :points

      t.timestamps
    end

    create_table :achievement_results do |t|
      t.text :title
      t.float :points

      t.timestamps
    end

    create_table :achievement_participations do |t|
      t.text :title
      t.float :points

      t.timestamps
    end

    create_table :achievement_fields do |t|
      t.text :title
      t.text :field_type

      t.timestamps
    end

    create_table :achievement_type_fields do |t|
      t.references :achievement_type, null: false, foreign_key: true
      t.references :achievement_field, null: false, foreign_key: true

      t.timestamps
    end

    create_table :achievement_field_answers do |t|
      t.references :achievement_field, null: false, foreign_key: true
      t.text :value

      t.timestamps
    end

    create_table :achievements do |t|
      t.references :achievement_type, null: false, foreign_key: true
      t.references :achievement_status, null: false, foreign_key: true
      t.references :achievement_result, null: false, foreign_key: true
      t.references :achievement_participation, null: false, foreign_key: true
      t.float :points
      t.references :achievement_field_answer, foreign_key: true

      t.timestamps
    end

    create_table :researcher_achievements do |t|
      t.references :researcher, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true

      t.timestamps
    end
  end
end

