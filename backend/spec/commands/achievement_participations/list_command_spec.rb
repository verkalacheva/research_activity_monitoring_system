# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementParticipations::ListCommand do
  describe '.call' do
    it 'returns catalog rows' do
      create_list(:achievement_participation, 2)

      result = described_class.call({ limit: 10, offset: 0 })

      expect(result).to be_success
      expect(result.value![:pagination][:total]).to eq(2)
    end
  end
end
