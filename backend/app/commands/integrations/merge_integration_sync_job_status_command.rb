# frozen_string_literal: true

module Integrations
  # Читает состояние задачи из Redis, сливает attrs, сериализует и записывает обратно.
  class MergeIntegrationSyncJobStatusCommand < BaseCommand
    def call(job_id:, attrs:)
      SyncJobStatus::PersistInteractor.call(job_id: job_id, attrs: attrs)
    end
  end
end
