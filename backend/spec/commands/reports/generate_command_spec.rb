# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::GenerateCommand do
  describe '.call' do
    it 'returns validation error when GenerateContract fails' do
      result = described_class.call(
        report_type: '',
        report_format: 'json',
        filters: [],
        sorts: [],
        limit: 0,
        offset: 0
      )

      expect(result).to be_failure
    end

    it 'delegates to ExecuteGenerateInteractor with validated params' do
      allow(Reports::ExecuteGenerateInteractor).to receive(:call).and_return(Dry::Monads::Success(data: {}))

      result = described_class.call(
        report_type: 'researchers',
        report_format: 'json',
        filters: [],
        sorts: [],
        limit: 5,
        offset: 0
      )

      expect(result).to be_success
      expect(Reports::ExecuteGenerateInteractor).to have_received(:call).once
    end
  end
end
