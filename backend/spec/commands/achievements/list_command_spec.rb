# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Achievements::ListCommand do
  describe '.call' do
    it 'returns paginated achievements' do
      create_list(:achievement, 2)

      result = described_class.call({ limit: 1, offset: 0 })

      expect(result).to be_success
      data = result.value!
      expect(data[:items].size).to eq(1)
      expect(data[:pagination][:total]).to eq(2)
    end

    it 'omits soft-deleted achievements' do
      a = create(:achievement)
      a.destroy

      result = described_class.call({ limit: 20, offset: 0 })
      ids = result.value![:items].map { |row| row['id'] }
      expect(ids).not_to include(a.id)
    end
  end
end
