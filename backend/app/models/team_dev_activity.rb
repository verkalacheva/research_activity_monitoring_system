class TeamDevActivity < ApplicationRecord
  belongs_to :team
  belongs_to :dev_employee_activity_type
end
