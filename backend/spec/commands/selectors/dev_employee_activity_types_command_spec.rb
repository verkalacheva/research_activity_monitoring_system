# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::DevEmployeeActivityTypesCommand do
  describe '.call' do
    it 'filters by query on title' do
      create(:dev_employee_activity_type, title: 'Уникальный вид деятельности XYZ')
      create(:dev_employee_activity_type, title: 'Другое')

      result = described_class.call({ limit: 20, offset: 0, query: 'xyz' })

      expect(result).to be_success
      titles = result.value![:items].map { |row| row[:title] }
      expect(titles).to include(a_string_matching(/XYZ/i))
      expect(titles.size).to eq(1)
    end

    it 'returns all when query is blank' do
      create_list(:dev_employee_activity_type, 2)

      result = described_class.call({ limit: 10, offset: 0 })

      expect(result.value![:items].size).to eq(2)
    end
  end
end
