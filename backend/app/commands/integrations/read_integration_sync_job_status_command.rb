# frozen_string_literal: true

module Integrations
  # Возвращает сериализованное состояние задачи для GET /integration_sync_jobs/:id.
  class ReadIntegrationSyncJobStatusCommand < BaseCommand
    def call(job_id:)
      SyncJobStatus::ReadInteractor.call(job_id: job_id)
    end
  end
end
