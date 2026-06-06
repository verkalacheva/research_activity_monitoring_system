# frozen_string_literal: true

class CreateInvitationsAndRefreshTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :invitations do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.references :researcher, null: false, foreign_key: true
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true

    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
  end
end
