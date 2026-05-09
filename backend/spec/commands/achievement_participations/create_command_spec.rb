# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementParticipations::CreateCommand do
  describe '.call' do
    it 'creates a participation row' do
      result = described_class.call(title: 'Индивидуальное участие', points: 1.0)

      expect(result).to be_success
      expect(result.value!.title).to include('Индивидуальное')
    end

    it 'fails without title' do
      expect(described_class.call(points: 0.5)).to be_failure
    end
  end
end
