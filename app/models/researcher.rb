class Researcher < ApplicationRecord
  has_many :researchers_teams
  has_many :teams, through: :researchers_teams
  has_many :led_teams, class_name: 'Team', foreign_key: 'leader_id'
  has_many :researcher_achievements
  has_many :achievements, through: :researcher_achievements
end

