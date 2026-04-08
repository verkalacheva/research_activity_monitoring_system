class CreateResearcherActivityDetails < ActiveRecord::Migration[7.0]
  def change
    create_table :researcher_activity_details do |t|
      t.bigint :researcher_id, null: false
      t.bigint :team_id, null: false
      t.string :activity_type, null: false
      t.string :external_id, null: false
      t.text :title
      t.string :repository
      t.string :url
      t.date :date
      t.string :state

      t.timestamps
    end

    add_index :researcher_activity_details, :researcher_id
    add_index :researcher_activity_details, :team_id
    add_index :researcher_activity_details, [:external_id, :activity_type, :researcher_id],
              unique: true, name: :idx_activity_details_uniqueness
    add_foreign_key :researcher_activity_details, :researchers
    add_foreign_key :researcher_activity_details, :teams
  end
end
