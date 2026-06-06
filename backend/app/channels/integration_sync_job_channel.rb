# frozen_string_literal: true

# Подписка: identifier { "channel": "IntegrationSyncJobChannel", "job_id": "<uuid>" }
# Стрим: integration_sync_job:<admin_id>:<uuid>
class IntegrationSyncJobChannel < ApplicationCable::Channel
  def subscribed
    job_id = (params[:job_id] || params['job_id']).to_s
    admin_id = current_user.admin_owner_id
    if job_id.blank? || admin_id.blank?
      reject
      return
    end

    data = Integrations::SyncJobStore.read(admin_id: admin_id, job_id: job_id)
    if data.blank?
      reject
      return
    end

    @job_id = job_id
    @admin_id = admin_id
    stream_from Integrations::SyncJobStore.cable_stream(admin_id: admin_id, job_id: job_id)
    push_snapshot!(data)
  end

  def unsubscribed
    # no-op
  end

  private

  def push_snapshot!(data = nil)
    data ||= Integrations::SyncJobStore.read(admin_id: @admin_id, job_id: @job_id)
    payload = IntegrationSyncJobStatusSerializer.new(data || {}).to_h
    transmit(payload)
  end
end
