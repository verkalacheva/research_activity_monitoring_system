# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::ListPageInteractor do
  describe '.call' do
    it 'returns serialized rows and pagination metadata' do
      create_list(:team, 3)

      result = described_class.call(
        scope: Team.order(:id),
        serializer_class: TeamListSerializer,
        limit: 2,
        offset: 0,
        count_scope: Team.all
      )

      expect(result).to be_success
      data = result.value!
      expect(data[:items].size).to eq(2)
      expect(data[:pagination]).to include(total: 3, limit: 2, offset: 0)
    end

    it 'applies offset' do
      create_list(:team, 2)
      result = described_class.call(
        scope: Team.order(:id),
        serializer_class: TeamListSerializer,
        limit: 1,
        offset: 1,
        count_scope: nil
      )
      expect(result.value![:items].size).to eq(1)
    end
  end
end
