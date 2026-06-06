class Researcher < ApplicationRecord
  include SoftDeletable
  include TenantScoped

  # Синхронизировано с выпадающим списком во frontend (researcher_form_screen.dart).
  DEGREE_LEVELS = %w[к.т.н. д.т.н. к.ф.-м.н. д.ф.-м.н. аспирант бакалавр магистрант].freeze

  has_many :researchers_teams, dependent: :destroy
  has_many :teams, -> { where(teams: { deleted_at: nil }) }, through: :researchers_teams
  has_many :led_teams, class_name: 'Team', foreign_key: 'leader_id', dependent: :nullify
  has_many :researcher_achievements, dependent: :destroy
  has_many :achievements, -> { where(achievements: { deleted_at: nil }) }, through: :researcher_achievements

  has_many :researcher_dev_activities, dependent: :destroy
  has_many :researcher_activity_details, dependent: :destroy

  before_validation :normalize_email

  validates :orcid_id, uniqueness: { scope: :admin_id }, allow_blank: true
  validates :openalex_id, uniqueness: { scope: :admin_id }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true


  def fullName
    [surname, name, second_name].compact.join(' ')
  end

  def is_leader
    led_teams.exists?
  end

  def dev_points(team)
    project_sum = team.dev_criteria_sum + team.dev_activities_sum
    activity_sum = researcher_dev_activities.where(team: team).includes(:dev_employee_activity_type).sum { |a| a.count * a.dev_employee_activity_type.points }
    (project_sum * activity_sum).round(2)
  end

  def total_dev_points
    teams.sum { |t| dev_points(t) }
  end

  # Multipliers per team so the frontend can recompute total_dev_points locally.
  def dev_team_multipliers
    teams.map { |t| { team_id: t.id, project_sum: t.dev_criteria_sum + t.dev_activities_sum } }
  end

  def as_json(options = {})
    super(options).merge(
      is_leader: is_leader,
      fullName: fullName,
      total_dev_points: total_dev_points,
      dev_team_multipliers: dev_team_multipliers,
      github: github
    )
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

end
