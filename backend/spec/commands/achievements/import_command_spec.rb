# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Achievements::ImportCommand do
  describe '.call' do
    it 'aggregates row outcomes' do
      wide = CSV.parse("a,b\n1,2\n3,4\n5,6\n7,8\n", headers: true)
      allow(Imports::ParseCsvFileInteractor).to receive(:call).and_return(Dry::Monads::Success(wide))
      allow(Achievements::ImportRowInteractor).to receive(:call).and_return(
        Dry::Monads::Success({ kind: :imported }),
        Dry::Monads::Success({ kind: :duplicate_skipped }),
        Dry::Monads::Success({ kind: :deleted_researcher_skipped }),
        Dry::Monads::Failure({ message: 'bad row' })
      )

      result = described_class.call(file_path: '/tmp/x.csv')

      expect(result).to be_success
      h = result.value!
      expect(h[:success]).to eq(1)
      expect(h[:skipped_duplicates]).to eq(1)
      expect(h[:skipped_deleted_researcher]).to eq(1)
      expect(h[:failure]).to eq(1)
      expect(h[:errors].size).to eq(1)
    end

    it 'propagates parse failure' do
      allow(Imports::ParseCsvFileInteractor).to receive(:call).and_return(
        Dry::Monads::Failure({ type: :import_error, message: 'parse failed' })
      )

      result = described_class.call(file_path: '/tmp/x.csv')
      expect(result).to be_failure
    end

    it 'skips blank rows' do
      blank_csv = CSV.parse("a,b\n,\n3,4\n", headers: true)
      allow(Imports::ParseCsvFileInteractor).to receive(:call).and_return(Dry::Monads::Success(blank_csv))
      allow(Achievements::ImportRowInteractor).to receive(:call).and_return(Dry::Monads::Success({ kind: :imported }))

      result = described_class.call(file_path: '/tmp/x.csv')
      expect(result.value![:success]).to eq(1)
    end
  end
end
