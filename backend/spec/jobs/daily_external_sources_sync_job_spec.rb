# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyExternalSourcesSyncJob do
  describe '#perform' do
    it 'does not write Redis when all phases return empty preview' do
      allow(Integrations::SyncPreviewCommand).to receive(:call).and_return(Dry::Monads::Success({ 'results' => [] }))
      expect(Integrations::PendingSyncResultsStore).not_to receive(:replace_daily_sync_entry)

      described_class.new.perform
    end

    it 'replaces daily_sync entry when phases return rows' do
      allow(Integrations::SyncPreviewCommand).to receive(:call).and_return(
        Dry::Monads::Success({ 'results' => [{ 'preview' => true }] })
      )

      expect(Integrations::PendingSyncResultsStore).to receive(:replace_daily_sync_entry).once do |entry|
        expect(entry).to include(
          'provider' => 'daily_sync',
          'label' => described_class::DAILY_SYNC_LABEL,
          'has_error' => false
        )
        expect(entry['results']).to be_an(Array)
        expect(entry['results'].size).to be >= 3
      end

      described_class.new.perform
    end

    it 'runs three preview phases when crawl is excluded' do
      allow(ENV).to receive(:[]).and_wrap_original do |method, key|
        key == 'DAILY_SYNC_EXCLUDE_CRAWL' ? 'true' : method.call(key)
      end

      call_count = 0
      allow(Integrations::SyncPreviewCommand).to receive(:call) do
        call_count += 1
        Dry::Monads::Success({ 'results' => [] })
      end

      described_class.new.perform

      expect(call_count).to eq(3)
    end
  end
end
