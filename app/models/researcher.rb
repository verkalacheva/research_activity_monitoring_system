class Researcher < ApplicationRecord
  has_many :researchers_teams, dependent: :destroy
  has_many :teams, through: :researchers_teams
  has_many :led_teams, class_name: 'Team', foreign_key: 'leader_id', dependent: :nullify
  has_many :researcher_achievements, dependent: :destroy
  has_many :achievements, through: :researcher_achievements

  def is_leader
    led_teams.exists?
  end

  def as_json(options = {})
    super(options).merge(is_leader: is_leader)
  end
end

