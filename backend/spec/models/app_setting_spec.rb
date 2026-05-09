# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppSetting, type: :model do
  describe 'validations' do
    it 'requires key' do
      expect(build(:app_setting, key: '')).not_to be_valid
    end

    it 'enforces unique key' do
      create(:app_setting, key: 'unique_setting_key')
      dup = build(:app_setting, key: 'unique_setting_key')
      expect(dup).not_to be_valid
    end
  end

  describe '.get' do
    it 'returns nil when missing' do
      expect(described_class.get('no_such_key')).to be_nil
    end

    it 'returns stored value' do
      create(:app_setting, key: 'k1', value: 'v1')
      expect(described_class.get('k1')).to eq('v1')
    end
  end

  describe '.set' do
    it 'creates and updates by key' do
      r1 = described_class.set('x', 'a')
      expect(r1).to be_persisted
      expect(described_class.get('x')).to eq('a')

      r2 = described_class.set('x', 'b')
      expect(r2.id).to eq(r1.id)
      expect(described_class.get('x')).to eq('b')
    end
  end

  describe '.all_as_hash' do
    it 'maps keys to values' do
      create(:app_setting, key: 'a', value: '1')
      create(:app_setting, key: 'b', value: '2')
      expect(described_class.all_as_hash).to include('a' => '1', 'b' => '2')
    end
  end

  describe '#sensitive? and #masked_value' do
    it 'masks github_token' do
      token = 'ghp_1234567890abcdefghij'
      s = build(:app_setting, key: 'github_token', value: token)
      expect(s).to be_sensitive
      expect(s.masked_value).to eq(token[0..3] + ('*' * (token.length - 8)) + token[-4..])
    end

    it 'masks short sensitive values entirely' do
      s = build(:app_setting, key: 'llm_api_key', value: 'short')
      expect(s.masked_value).to eq('*****')
    end

    it 'returns plain value for non-sensitive keys' do
      s = build(:app_setting, key: 'llm_model_name', value: 'gpt-4o')
      expect(s).not_to be_sensitive
      expect(s.masked_value).to eq('gpt-4o')
    end

    it 'returns nil when value is blank' do
      s = build(:app_setting, key: 'github_token', value: '')
      expect(s.masked_value).to be_nil
    end
  end
end
