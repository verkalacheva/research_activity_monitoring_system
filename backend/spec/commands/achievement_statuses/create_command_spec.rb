# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementStatuses::CreateCommand do
  describe '.call' do
    it 'creates a status from valid params' do
      result = described_class.call(title: 'Новый статус', points: 2.5)

      expect(result).to be_success
      expect(result.value!).to be_a(AchievementStatus)
      expect(result.value!.title).to eq('Новый статус')
    end

    it 'fails contract validation without title' do
      result = described_class.call(points: 1.0)
      expect(result).to be_failure
    end
  end
end
