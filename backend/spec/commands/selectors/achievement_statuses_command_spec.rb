# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::AchievementStatusesCommand do
  describe '.call' do
    it 'filters by title query' do
      create(:achievement_status, title: 'Статус NNN особый')
      create(:achievement_status, title: 'Прочее')

      result = described_class.call({ limit: 10, offset: 0, query: 'nnn' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
    end
  end
end
