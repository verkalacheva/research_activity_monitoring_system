# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::ListCommand do
  describe '.call' do
    it 'returns paginated team rows' do
      create_list(:team, 2)

      result = described_class.call({ limit: 10, offset: 0 })

      expect(result).to be_success
      data = result.value!
      expect(data[:items].size).to eq(2)
      expect(data[:pagination][:total]).to eq(2)
      expect(data[:pagination][:limit]).to eq(10)
    end

    it 'uses default limit when limit is not positive' do
      create(:team)
      result = described_class.call({ limit: 0, offset: 0 })
      expect(result.value![:pagination][:limit]).to eq(20)
    end

    it 'does not list soft-deleted teams' do
      kept = create(:team)
      deleted = create(:team)
      deleted.destroy

      result = described_class.call({ limit: 20, offset: 0 })
      ids = result.value![:items].map { |row| row['id'] }
      expect(ids).to include(kept.id)
      expect(ids).not_to include(deleted.id)
    end
  end
end
