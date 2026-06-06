# frozen_string_literal: true

module Integrations
  module SyncJobStatus
    # Сливает атрибуты в состояние задачи в Redis и сохраняет сериализованный снимок.
    class PersistInteractor < BaseInteractor
      def call(job_id:, attrs:)
        return failure(:validation_error, 'job_id is required') if job_id.blank?

        admin_id = attrs[:admin_id] || attrs['admin_id'] || Current.admin_id
        return failure(:validation_error, 'admin_id is required') if admin_id.blank?

        cur = Integrations::SyncJobStore.read(admin_id: admin_id, job_id: job_id) || {}
        merged = cur.deep_stringify_keys.merge(attrs.stringify_keys).merge('admin_id' => admin_id.to_s)
        payload = IntegrationSyncJobStatusSerializer.new(merged).to_h
        Integrations::SyncJobStore.write!(admin_id: admin_id, job_id: job_id, hash: payload)
        stream = Integrations::SyncJobStore.cable_stream(admin_id: admin_id, job_id: job_id)
        ActionCable.server.broadcast(stream, payload)
        success(payload)
      end
    end
  end
end
