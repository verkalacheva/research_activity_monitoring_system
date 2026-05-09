# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::AchievementTypesCommand do
  describe '.call' do
    it 'filters by title query' do
      create(:achievement_type, title: 'Тип с меткой MMM')
      create(:achievement_type, title: 'Иной тип')

      result = described_class.call({ limit: 10, offset: 0, query: 'mmm' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
    end
  end
end
