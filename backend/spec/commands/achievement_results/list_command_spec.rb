# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementResults::ListCommand do
  describe '.call' do
    it 'returns catalog rows' do
      create_list(:achievement_result, 2)

      result = described_class.call({ limit: 10, offset: 0 })

      expect(result).to be_success
      expect(result.value![:pagination][:total]).to eq(2)
    end
  end
end
