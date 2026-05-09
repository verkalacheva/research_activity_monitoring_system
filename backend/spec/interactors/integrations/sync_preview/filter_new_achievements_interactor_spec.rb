# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::SyncPreview::FilterNewAchievementsInteractor do
  describe '.normalize_title_key' do
    it 'normalizes unicode and punctuation' do
      expect(described_class.normalize_title_key('  Hello World  ')).to eq('hello world')
    end

    it 'returns empty for blank' do
      expect(described_class.normalize_title_key(nil)).to eq('')
    end
  end
end
