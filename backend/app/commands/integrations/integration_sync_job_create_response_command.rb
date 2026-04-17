# frozen_string_literal: true

module Integrations
  # Тело ответа POST /integration_sync_jobs (job_id + status).
  class IntegrationSyncJobCreateResponseCommand < BaseCommand
    def call(job_id:, status: 'queued')
      SyncJobStatus::CreateResponseInteractor.call(job_id: job_id, status: status)
    end
  end
end
