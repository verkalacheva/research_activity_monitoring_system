# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::TeamsCommand do
  describe '.call' do
    it 'filters teams by title query' do
      create(:team, title: 'Команда QQQ уникальная')
      create(:team, title: 'Другой проект')

      result = described_class.call({ limit: 10, offset: 0, query: 'qqq' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
      expect(result.value![:items].first[:title]).to include('QQQ')
    end
  end
end
