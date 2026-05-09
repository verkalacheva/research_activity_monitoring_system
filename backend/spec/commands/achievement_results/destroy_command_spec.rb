# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementResults::DestroyCommand do
  describe '.call' do
    it 'soft-deletes the result' do
      rec = create(:achievement_result)

      result = described_class.call(rec.id)

      expect(result).to be_success
      expect(rec.reload.deleted?).to be true
    end

    it 'returns not_found for unknown id' do
      expect(described_class.call(0)).to be_failure
    end
  end
end
