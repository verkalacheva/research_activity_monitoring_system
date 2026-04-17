# frozen_string_literal: true

module Integrations
  module SyncJobStatus
    # Читает задачу из Redis и отдаёт сериализованное тело для API.
    class ReadInteractor < BaseInteractor
      def call(job_id:)
        return failure(:validation_error, 'job_id is required') if job_id.blank?

        data = Integrations::SyncJobStore.read(job_id)
        return failure(:not_found, 'integration sync job not found') if data.blank?

        success(IntegrationSyncJobStatusSerializer.new(data).to_h)
      end
    end
  end
end
