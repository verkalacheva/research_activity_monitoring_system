class AddOrcidIdToResearchers < ActiveRecord::Migration[7.0]
  def change
    add_column :researchers, :orcid_id, :text
    add_index :researchers, :orcid_id, unique: true
  end
end

