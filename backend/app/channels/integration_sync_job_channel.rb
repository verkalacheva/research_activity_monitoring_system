# frozen_string_literal: true

# Подписка: identifier { "channel": "IntegrationSyncJobChannel", "job_id": "<uuid>" }
# Стрим: integration_sync_job:<uuid>
class IntegrationSyncJobChannel < ApplicationCable::Channel
  def subscribed
    job_id = (params[:job_id] || params['job_id']).to_s
    if job_id.blank?
      reject
      return
    end

    @job_id = job_id
    stream_from "integration_sync_job:#{@job_id}"
    push_snapshot!
  end

  def unsubscribed
    # no-op
  end

  private

  def push_snapshot!
    data = Integrations::SyncJobStore.read(@job_id)
    payload = IntegrationSyncJobStatusSerializer.new(data || {}).to_h
    transmit(payload)
  end
end
