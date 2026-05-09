# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::AchievementResultsCommand do
  describe '.call' do
    it 'filters by title query' do
      create(:achievement_result, title: 'Результат PPP')
      create(:achievement_result, title: 'Иное')

      result = described_class.call({ limit: 10, offset: 0, query: 'ppp' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
    end
  end
end
