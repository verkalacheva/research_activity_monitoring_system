# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::AugmentReportParamsInteractor do
  describe '.call' do
    it 'moves unknown scalar params into filters with operator' do
      result = described_class.call(params: {
                                      report_type: 'researchers',
                                      report_format: 'json',
                                      subject_area: 'Информатика',
                                      subject_area_operator: 'eq'
                                    })

      expect(result).to be_success
      filters = result.value![:filters]
      expect(filters).to include(
        hash_including(field: 'subject_area', operator: 'eq', value: 'Информатика')
      )
    end

    it 'joins array values for in operator' do
      result = described_class.call(params: {
                                      report_type: 'researchers',
                                      report_format: 'json',
                                      ids: %w[1 2 3]
                                    })

      f = result.value![:filters].find { |h| h[:field] == 'ids' }
      expect(f[:operator]).to eq('in')
      expect(f[:value]).to eq('1,2,3')
    end
  end
end
