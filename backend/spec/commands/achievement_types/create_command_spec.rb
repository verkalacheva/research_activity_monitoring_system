# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementTypes::CreateCommand do
  describe '.call' do
    it 'creates a type with title and points' do
      result = described_class.call(title: 'Новый тип достижения', points: 4.0, icon_name: 'star')

      expect(result).to be_success
      expect(result.value!).to be_a(AchievementType)
      expect(result.value!.title).to eq('Новый тип достижения')
      expect(result.value!.points).to eq(4.0)
    end

    it 'fails without title' do
      expect(described_class.call(points: 1.0)).to be_failure
    end
  end
end
