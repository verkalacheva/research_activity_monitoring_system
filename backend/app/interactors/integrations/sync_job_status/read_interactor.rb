# frozen_string_literal: true

module Integrations
  module SyncJobStatus
    # Читает задачу из Redis и отдаёт сериализованное тело для API.
    class ReadInteractor < BaseInteractor
      def call(job_id:)
        return failure(:validation_error, 'job_id is required') if job_id.blank?
        return failure(:forbidden, 'admin context required') if Current.admin_id.blank?

        data = Integrations::SyncJobStore.read(admin_id: Current.admin_id, job_id: job_id)
        return failure(:not_found, 'integration sync job not found') if data.blank?

        success(IntegrationSyncJobStatusSerializer.new(data).to_h)
      end
    end
  end
end
