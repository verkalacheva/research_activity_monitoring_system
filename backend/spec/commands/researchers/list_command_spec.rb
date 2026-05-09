# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Researchers::ListCommand do
  describe '.call' do
    it 'returns paginated researcher rows with is_leader flag' do
      leader = create(:researcher)
      create(:team, :with_leader, leader: leader)
      create(:researcher)

      result = described_class.call({ limit: 10, offset: 0 })

      expect(result).to be_success
      data = result.value!
      expect(data[:pagination][:total]).to eq(2)
      leader_row = data[:items].find { |r| r[:id] == leader.id }
      expect(leader_row[:is_leader]).to be true
    end

    it 'excludes soft-deleted researchers from total' do
      r = create(:researcher)
      r.destroy

      result = described_class.call({ limit: 10, offset: 0 })
      expect(result.value![:pagination][:total]).to eq(0)
    end
  end
end
