# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementTypes::ListCommand do
  describe '.call' do
    it 'returns achievement types with default limit 100' do
      create_list(:achievement_type, 2)

      result = described_class.call({ limit: 0, offset: 0 })

      expect(result).to be_success
      expect(result.value![:pagination][:limit]).to eq(100)
      expect(result.value![:pagination][:total]).to eq(2)
    end
  end
end
