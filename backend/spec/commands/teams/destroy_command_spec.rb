# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::DestroyCommand do
  describe '.call' do
    it 'soft-deletes team and clears join rows' do
      team = create(:team)
      crit = create(:dev_project_criterion)
      TeamDevCriterion.create!(team: team, dev_project_criterion: crit)
      det = create(:dev_employee_activity_type)
      TeamDevActivity.create!(team: team, dev_employee_activity_type: det, count: 1, date: Date.current)

      result = described_class.call(team.id)

      expect(result).to be_success
      expect(team.reload.deleted?).to be true
      expect(TeamDevCriterion.where(team_id: team.id)).to be_empty
      expect(TeamDevActivity.where(team_id: team.id)).to be_empty
    end

    it 'returns not_found for missing id' do
      result = described_class.call(0)
      expect(result).to be_failure
    end
  end
end
