# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementStatuses::UpdateCommand do
  describe '.call' do
    it 'updates an existing status' do
      status = create(:achievement_status, title: 'Старое')

      result = described_class.call(status.id, title: 'Новое название', points: 3.0)

      expect(result).to be_success
      expect(status.reload.title).to eq('Новое название')
      expect(status.points).to eq(3.0)
    end

    it 'returns not_found for unknown id' do
      result = described_class.call(0, title: 'X', points: 1.0)
      expect(result).to be_failure
    end
  end
end
