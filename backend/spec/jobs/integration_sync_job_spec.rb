# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntegrationSyncJob do
  describe '#perform' do
    before do
      allow(Integrations::SyncJobCancellation).to receive(:requested?).and_return(false)
      allow(Integrations::SyncJobCancellation).to receive(:clear!)
    end

    it 'does nothing when job_id is blank' do
      expect(Integrations::MergeIntegrationSyncJobStatusCommand).not_to receive(:call)
      described_class.new.perform('', { 'provider' => 'orcid' })
    end

    it 'sets running then complete when preview succeeds' do
      allow(Integrations::MergeIntegrationSyncJobStatusCommand).to receive(:call).and_return(Dry::Monads::Success(:ok))
      allow(Integrations::SyncPreviewCommand).to receive(:call).and_return(Dry::Monads::Success({ 'results' => [] }))

      described_class.new.perform('job-ok', { 'provider' => 'orcid', 'researcher_id' => 42 })

      expect(Integrations::MergeIntegrationSyncJobStatusCommand).to have_received(:call).with(
        hash_including(job_id: 'job-ok', attrs: hash_including('status' => 'running'))
      )
      expect(Integrations::MergeIntegrationSyncJobStatusCommand).to have_received(:call).with(
        hash_including(job_id: 'job-ok', attrs: hash_including('status' => 'complete', 'results' => []))
      )
    end

    it 'sets failed when preview returns a failure' do
      allow(Integrations::MergeIntegrationSyncJobStatusCommand).to receive(:call).and_return(Dry::Monads::Success(:ok))
      failure_payload = {
        type: :service_unavailable,
        errors: { message: 'upstream unavailable', rate_limit: true }
      }
      allow(Integrations::SyncPreviewCommand).to receive(:call).and_return(Dry::Monads::Failure(failure_payload))

      described_class.new.perform('job-fail', { 'provider' => 'openalex' })

      expect(Integrations::MergeIntegrationSyncJobStatusCommand).to have_received(:call).with(
        hash_including(
          job_id: 'job-fail',
          attrs: hash_including(
            'status' => 'failed',
            'error' => 'upstream unavailable',
            'rate_limit' => true
          )
        )
      )
    end
  end
end
