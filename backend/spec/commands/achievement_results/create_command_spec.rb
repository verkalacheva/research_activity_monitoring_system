# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementResults::CreateCommand do
  describe '.call' do
    it 'creates a result' do
      result = described_class.call(title: 'Итог теста', points: 1.5)

      expect(result).to be_success
      expect(result.value!.title).to eq('Итог теста')
    end

    it 'fails without title' do
      expect(described_class.call(points: 2.0)).to be_failure
    end
  end
end
