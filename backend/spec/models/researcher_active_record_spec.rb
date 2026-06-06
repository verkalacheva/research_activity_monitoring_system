# frozen_string_literal: true

require 'rails_helper'

# Реальная модель Researcher; см. также researcher_spec.rb (чистая логика без AR).
RSpec.describe Researcher, type: :model, needs_tenant_context: true do
  describe 'validations' do
    it 'rejects duplicate orcid_id' do
      create(:researcher, orcid_id: '0000-0001-1111-1111')
      dup = build(:researcher, orcid_id: '0000-0001-1111-1111')
      expect(dup).not_to be_valid
      expect(dup.errors[:orcid_id]).to be_present
    end

    it 'rejects duplicate openalex_id' do
      create(:researcher, openalex_id: 'W1234567890')
      dup = build(:researcher, openalex_id: 'W1234567890')
      expect(dup).not_to be_valid
    end

    it 'allows blank external ids' do
      expect(build(:researcher, orcid_id: '', openalex_id: '')).to be_valid
    end
  end

  describe '#fullName' do
    it 'joins name parts' do
      r = create(:researcher, surname: 'Петров', name: 'Пётр', second_name: nil)
      expect(r.fullName).to eq('Петров Пётр')
    end
  end

  describe '#is_leader' do
    it 'is true when leading a team' do
      leader = create(:researcher)
      create(:team, :with_leader, leader: leader)
      expect(leader.reload.is_leader).to be true
    end

    it 'is false otherwise' do
      expect(create(:researcher).is_leader).to be false
    end
  end

  describe '#dev_points and #total_dev_points' do
    it 'computes project_sum * activity_sum' do
      researcher = create(:researcher)
      team = create(:team, researchers: [researcher])

      crit = create(:dev_project_criterion, points: 2.0)
      TeamDevCriterion.create!(team: team, dev_project_criterion: crit)

      det = create(:dev_employee_activity_type, points: 1.5)
      TeamDevActivity.create!(
        team: team,
        dev_employee_activity_type: det,
        count: 2,
        date: Date.current
      )

      create(
        :researcher_dev_activity,
        researcher: researcher,
        team: team,
        dev_employee_activity_type: create(:dev_employee_activity_type, points: 2.0),
        count: 3
      )

      # project_sum = 2 + (2 * 1.5) = 5; activity_sum = 3 * 2 = 6 -> 30.0
      expect(researcher.reload.dev_points(team.reload)).to eq(30.0)
      expect(researcher.total_dev_points).to eq(30.0)
    end
  end

  describe '#dev_team_multipliers' do
    it 'returns project_sum per team' do
      researcher = create(:researcher)
      t1 = create(:team, researchers: [researcher])
      t2 = create(:team, researchers: [researcher])

      TeamDevCriterion.create!(team: t1, dev_project_criterion: create(:dev_project_criterion, points: 10.0))
      det = create(:dev_employee_activity_type, points: 1.0)
      TeamDevActivity.create!(team: t2, dev_employee_activity_type: det, count: 5, date: Date.current)

      mult = researcher.reload.dev_team_multipliers
      expect(mult.size).to eq(2)
      t1_row = mult.find { |m| m[:team_id] == t1.id }
      t2_row = mult.find { |m| m[:team_id] == t2.id }
      expect(t1_row[:project_sum]).to eq(10.0)
      expect(t2_row[:project_sum]).to eq(5.0)
    end
  end

  describe '#as_json' do
    it 'includes computed fields' do
      r = create(:researcher, :with_github)
      # merge(...) adds symbol keys; column keys from super stay strings
      json = r.as_json.with_indifferent_access
      expect(json[:fullName]).to eq(r.fullName)
      expect(json).to have_key(:total_dev_points)
      expect(json).to have_key(:dev_team_multipliers)
      expect(json[:github]).to include('researcher')
    end
  end
end
