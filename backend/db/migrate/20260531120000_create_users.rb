# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: 'admin'
      t.references :admin, foreign_key: { to_table: :users }, index: true
      t.references :researcher, foreign_key: true, index: false
      t.string :full_name
      t.boolean :is_active, null: false, default: true
      t.datetime :last_sign_in_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :researcher_id, unique: true, where: 'researcher_id IS NOT NULL'
  end
end
