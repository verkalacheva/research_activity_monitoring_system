# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::DevProjectCriteriaCommand do
  describe '.call' do
    it 'filters by query on title' do
      create(:dev_project_criterion, title: 'Критерий ABC специальный')
      create(:dev_project_criterion, title: 'Иной')

      result = described_class.call({ limit: 20, offset: 0, query: 'abc' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
      expect(result.value![:items].first[:title]).to include('ABC')
    end
  end
end
