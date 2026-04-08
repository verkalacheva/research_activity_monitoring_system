class DevProjectCriterion < ApplicationRecord
  has_many :team_dev_criteria, dependent: :destroy
  has_many :teams, through: :team_dev_criteria

  validates :title, presence: true, uniqueness: true
end
