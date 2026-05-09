# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Imports::ParseCsvFileInteractor do
  describe '.call' do
    it 'parses comma-separated UTF-8 CSV' do
      Tempfile.create(['import', '.csv']) do |f|
        f.write("name,value\nfoo,1\n")
        f.close

        result = described_class.call(file_path: f.path)
        expect(result).to be_success
        expect(result.value!.headers).to eq(%w[name value])
        expect(result.value!.first['name']).to eq('foo')
      end
    end

    it 'detects semicolon separator' do
      Tempfile.create(['import', '.csv']) do |f|
        f.write("a;b\n1;2\n")
        f.close

        result = described_class.call(file_path: f.path)
        expect(result).to be_success
        expect(result.value!.first['a']).to eq('1')
      end
    end

    it 'strips UTF-8 BOM' do
      Tempfile.create(['import', '.csv']) do |f|
        f.binmode
        f.write("\xEF\xBB\xBF")
        f.write("h1,h2\nv1,v2\n")
        f.close

        result = described_class.call(file_path: f.path)
        expect(result).to be_success
        expect(result.value!.headers).to eq(%w[h1 h2])
      end
    end

    it 'returns failure for missing file' do
      result = described_class.call(file_path: '/no/such/file.csv')
      expect(result).to be_failure
    end
  end
end
