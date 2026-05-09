# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Selectors::ResearchersCommand do
  describe '.call' do
    it 'filters by query across name fields' do
      create(:researcher, surname: 'УникальнаяФамилияZZZ', name: 'Иван')
      create(:researcher, surname: 'Другой', name: 'Пётр')

      result = described_class.call({ limit: 20, offset: 0, query: 'zzz' })

      expect(result).to be_success
      expect(result.value![:items].size).to eq(1)
      expect(result.value![:items].first[:surname]).to include('ZZZ')
    end

    it 'filters by degree_level' do
      create(:researcher, degree_level: 'к.т.н.')
      create(:researcher, degree_level: 'магистрант')

      result = described_class.call({ limit: 20, offset: 0, degree_level: 'к.т.н.' })

      expect(result.value![:items].map { |r| r[:degree_level] }.uniq).to eq(['к.т.н.'])
    end
  end
end
