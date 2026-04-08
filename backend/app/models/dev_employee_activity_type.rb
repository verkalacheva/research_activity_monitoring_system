class DevEmployeeActivityType < ApplicationRecord
  has_many :researcher_dev_activities, dependent: :destroy
  
  validates :title, presence: true, uniqueness: true
end
