class DropResearcherCommitDetails < ActiveRecord::Migration[7.0]
  def up
    drop_table :researcher_commit_details, if_exists: true
  end

  def down
    create_table :researcher_commit_details do |t|
      t.bigint :researcher_id, null: false
      t.bigint :team_id, null: false
      t.string :sha, null: false
      t.string :repository
      t.text :message
      t.date :committed_at
      t.timestamps
    end
  end
end
