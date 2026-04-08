class TeamDevCriterion < ApplicationRecord
  belongs_to :team
  belongs_to :dev_project_criterion
end
