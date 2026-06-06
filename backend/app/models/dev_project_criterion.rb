class DevProjectCriterion < ApplicationRecord
  include TenantScoped

  has_many :team_dev_criteria, dependent: :destroy
  has_many :teams, through: :team_dev_criteria

  validates :title, presence: true
  validates :check_key, uniqueness: { scope: :admin_id }, allow_nil: true
end
