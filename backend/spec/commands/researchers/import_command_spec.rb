# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Researchers::ImportCommand do
  describe '.call' do
    let(:csv) { CSV.parse("a,b\n1,2\n3,4\n", headers: true) }

    it 'counts successes and failures' do
      allow(Imports::ParseCsvFileInteractor).to receive(:call).and_return(Dry::Monads::Success(csv))
      allow(Researchers::ImportRowInteractor).to receive(:call).and_return(
        Dry::Monads::Success(true),
        Dry::Monads::Failure({ message: 'dup' })
      )

      result = described_class.call(file_path: '/tmp/x.csv')

      expect(result).to be_success
      expect(result.value![:success]).to eq(1)
      expect(result.value![:failure]).to eq(1)
      expect(result.value![:errors].size).to eq(1)
    end

    it 'propagates parse failure' do
      allow(Imports::ParseCsvFileInteractor).to receive(:call).and_return(
        Dry::Monads::Failure({ type: :import_error, message: 'no csv' })
      )

      expect(described_class.call(file_path: '/tmp/x.csv')).to be_failure
    end
  end
end
