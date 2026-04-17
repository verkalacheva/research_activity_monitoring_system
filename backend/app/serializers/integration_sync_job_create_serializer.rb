# frozen_string_literal: true

class IntegrationSyncJobCreateSerializer < BaseSerializer
  def to_h
    {
      job_id: object[:job_id] || object['job_id'],
      status: object[:status] || object['status'] || 'queued'
    }
  end
end
