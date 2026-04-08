class AddOpenalexIdToResearchers < ActiveRecord::Migration[7.0]
  def change
    add_column :researchers, :openalex_id, :text
    add_index :researchers, :openalex_id
  end
end
