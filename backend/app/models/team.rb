class Team < ApplicationRecord
  include SoftDeletable
  belongs_to :leader, class_name: 'Researcher', optional: true
  has_many :researchers_teams, dependent: :destroy
  has_many :researchers, -> { where(researchers: { deleted_at: nil }).order(:surname, :name, :second_name) }, through: :researchers_teams
  
  has_many :team_dev_criteria, dependent: :destroy
  has_many :dev_project_criteria, through: :team_dev_criteria
  has_many :team_dev_activities, dependent: :destroy
  has_many :researcher_dev_activities, dependent: :destroy

  def dev_criteria_sum
    dev_project_criteria.sum(:points)
  end

  def dev_activities_sum
    team_dev_activities.includes(:dev_employee_activity_type).sum { |a| a.count * a.dev_employee_activity_type.points }
  end

  def as_json(options = {})
    super(options).merge(
      dev_criteria_sum: dev_criteria_sum,
      dev_activities_sum: dev_activities_sum,
      github_repo_url: github_repo_url,
      dev_project_criteria: dev_project_criteria.order(:title).as_json
    )
  end
end

