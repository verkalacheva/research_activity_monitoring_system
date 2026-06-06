# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :researchers, foreign_key: :admin_id, dependent: :destroy, inverse_of: :admin
  has_many :teams, foreign_key: :admin_id, dependent: :destroy, inverse_of: :admin
  has_many :refresh_tokens, dependent: :destroy
  has_many :app_settings, foreign_key: :admin_id, dependent: :destroy, inverse_of: :admin

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(is_active: true) }

  def admin_owner_id
    id
  end

  def as_auth_json
    {
      id: id,
      email: email,
      full_name: full_name
    }
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
