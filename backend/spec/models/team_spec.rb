# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  describe '#dev_criteria_sum' do
    it 'sums linked criterion points' do
      team = create(:team)
      c1 = create(:dev_project_criterion, points: 2.5)
      c2 = create(:dev_project_criterion, points: 1.5)
      TeamDevCriterion.create!(team: team, dev_project_criterion: c1)
      TeamDevCriterion.create!(team: team, dev_project_criterion: c2)
      expect(team.reload.dev_criteria_sum).to eq(4.0)
    end

    it 'returns 0 when no criteria' do
      expect(create(:team).dev_criteria_sum).to eq(0)
    end
  end

  describe '#dev_activities_sum' do
    it 'sums count * activity_type.points' do
      team = create(:team)
      det = create(:dev_employee_activity_type, points: 2.0)
      TeamDevActivity.create!(
        team: team,
        dev_employee_activity_type: det,
        count: 3,
        date: Date.current
      )
      expect(team.reload.dev_activities_sum).to eq(6.0)
    end
  end

  describe '#as_json' do
    it 'includes aggregated fields' do
      team = create(:team, :with_github, title: 'Alpha')
      crit = create(:dev_project_criterion, title: 'Zeta', points: 1.0)
      TeamDevCriterion.create!(team: team, dev_project_criterion: crit)

      json = team.reload.as_json.with_indifferent_access
      expect(json[:dev_criteria_sum]).to eq(1.0)
      expect(json[:github_repo_url]).to include('github.com')
      expect(json[:dev_project_criteria]).to be_an(Array)
    end
  end

  describe 'SoftDeletable' do
    it 'soft-deletes via destroy' do
      team = create(:team)
      team.destroy
      expect(team.reload.deleted?).to be true
      expect(described_class.kept).not_to include(team)
    end

    it 'restore clears deleted_at' do
      team = create(:team)
      team.destroy
      team.restore
      expect(team.reload).to be_kept
    end
  end
end
