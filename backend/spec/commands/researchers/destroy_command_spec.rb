# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Researchers::DestroyCommand do
  describe '.call' do
    it 'soft-deletes researcher and clears team links' do
      researcher = create(:researcher)
      create(:team, researchers: [researcher])

      result = described_class.call(researcher.id)

      expect(result).to be_success
      expect(researcher.reload.deleted?).to be true
      expect(ResearchersTeam.where(researcher_id: researcher.id)).to be_empty
    end

    it 'returns not_found for missing id' do
      result = described_class.call(0)
      expect(result).to be_failure
    end
  end
end
