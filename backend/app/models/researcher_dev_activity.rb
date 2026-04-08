class ResearcherDevActivity < ApplicationRecord
  belongs_to :researcher
  belongs_to :team
  belongs_to :dev_employee_activity_type

  validates :count, numericality: true
end
