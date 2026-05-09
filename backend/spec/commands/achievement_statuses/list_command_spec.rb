# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementStatuses::ListCommand do
  describe '.call' do
    it 'returns catalog rows and total' do
      create_list(:achievement_status, 2)

      result = described_class.call({ limit: 50, offset: 0 })

      expect(result).to be_success
      data = result.value!
      expect(data[:pagination][:total]).to eq(2)
      expect(data[:items].size).to eq(2)
      expect(data[:items].first).to include('id', 'title', 'points')
    end

    it 'hides soft-deleted records' do
      s = create(:achievement_status)
      s.destroy

      result = described_class.call({ limit: 100, offset: 0 })
      ids = result.value![:items].map { |row| row['id'] }
      expect(ids).not_to include(s.id)
    end
  end
end
