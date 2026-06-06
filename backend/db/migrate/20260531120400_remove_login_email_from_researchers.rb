# frozen_string_literal: true

class RemoveLoginEmailFromResearchers < ActiveRecord::Migration[7.0]
  def change
    remove_index :researchers, :login_email, if_exists: true
    remove_column :researchers, :login_email, :string, if_exists: true
  end
end
