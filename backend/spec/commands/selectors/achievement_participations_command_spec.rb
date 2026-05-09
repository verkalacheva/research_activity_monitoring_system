# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::AchievementParticipationsCommand do
  describe '.call' do
    it 'filters by title query' do
      create(:achievement_participation, title: 'Участие OOO')
      create(:achievement_participation, title: 'Другое')

      result = described_class.call({ limit: 10, offset: 0, query: 'ooo' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
    end
  end
end
