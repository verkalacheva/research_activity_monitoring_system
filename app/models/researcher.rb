class Researcher < ApplicationRecord
  include SoftDeletable

  has_many :researchers_teams, dependent: :destroy
  has_many :teams, through: :researchers_teams
  has_many :led_teams, class_name: 'Team', foreign_key: 'leader_id', dependent: :nullify
  has_many :researcher_achievements, dependent: :destroy
  has_many :achievements, -> { where(achievements: { deleted_at: nil }) }, through: :researcher_achievements

  validates :orcid_id, uniqueness: true, allow_blank: true
  validates :openalex_id, uniqueness: true, allow_blank: true

  def fullName
    [surname, name, second_name].compact.join(' ')
  end

  def is_leader
    led_teams.exists?
  end

  def as_json(options = {})
    super(options).merge(is_leader: is_leader, fullName: fullName)
  end
end

