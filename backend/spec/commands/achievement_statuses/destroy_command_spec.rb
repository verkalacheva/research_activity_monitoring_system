# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementStatuses::DestroyCommand do
  describe '.call' do
    it 'soft-deletes the status' do
      status = create(:achievement_status)

      result = described_class.call(status.id)

      expect(result).to be_success
      expect(status.reload.deleted?).to be true
    end

    it 'returns not_found for unknown id' do
      expect(described_class.call(0)).to be_failure
    end
  end
end
