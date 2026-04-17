# frozen_string_literal: true

module Integrations
  module SyncJobStatus
    # Тело ответа POST /integration_sync_jobs (job_id + status).
    class CreateResponseInteractor < BaseInteractor
      def call(job_id:, status: 'queued')
        return failure(:validation_error, 'job_id is required') if job_id.blank?

        success(
          IntegrationSyncJobCreateSerializer.new({ job_id: job_id, status: status }).to_h
        )
      end
    end
  end
end
