class DevEmployeeActivityType < ApplicationRecord
  include TenantScoped

  has_many :researcher_dev_activities, dependent: :destroy

  validates :title, presence: true
  validates :check_key, uniqueness: { scope: :admin_id }, allow_nil: true
end
