class AddFieldsToResearchers < ActiveRecord::Migration[7.0]
  def change
    add_column :researchers, :email, :text
    add_column :researchers, :telegram, :text
    add_column :researchers, :isu_number, :text
    add_column :researchers, :faculty, :text
    add_column :researchers, :employment_status, :text
  end
end


