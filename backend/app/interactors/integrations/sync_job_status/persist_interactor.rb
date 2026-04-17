# frozen_string_literal: true

module Integrations
  module SyncJobStatus
    # Сливает атрибуты в состояние задачи в Redis и сохраняет сериализованный снимок.
    class PersistInteractor < BaseInteractor
      def call(job_id:, attrs:)
        return failure(:validation_error, 'job_id is required') if job_id.blank?

        cur = Integrations::SyncJobStore.read(job_id) || {}
        merged = cur.deep_stringify_keys.merge(attrs.stringify_keys)
        payload = IntegrationSyncJobStatusSerializer.new(merged).to_h
        Integrations::SyncJobStore.write!(job_id, payload)
        ActionCable.server.broadcast("integration_sync_job:#{job_id}", payload)
        success(payload)
      end
    end
  end
end
