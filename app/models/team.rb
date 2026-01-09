class Team < ApplicationRecord
  belongs_to :leader, class_name: 'Researcher', optional: true
  has_many :researchers_teams, dependent: :destroy
  has_many :researchers, through: :researchers_teams
end

