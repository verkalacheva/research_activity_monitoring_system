# frozen_string_literal: true

class IntegrationSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :integrations, retry: 1

  def perform(job_id, payload)
    return if job_id.blank?

    Integrations::MergeIntegrationSyncJobStatusCommand.call(
      job_id: job_id,
      attrs: { 'status' => 'running' }
    )

    cancel_proc = -> { Integrations::SyncJobCancellation.requested?(job_id) }

    cmd_params = ActionController::Parameters.new(payload)
      .permit(:provider, :researcher_id, :team_id, :scope, :url, :llm_provider)
      .to_h
      .symbolize_keys
      .merge(cancel_proc: cancel_proc)

    result = Integrations::SyncPreviewCommand.call(cmd_params)

    cancelled = Integrations::SyncJobCancellation.requested?(job_id)
    Integrations::SyncJobCancellation.clear!(job_id)

    if cancelled
      Integrations::MergeIntegrationSyncJobStatusCommand.call(
        job_id: job_id,
        attrs: {
          'status' => 'cancelled',
          'error' => nil,
          'rate_limit' => false,
          'results' => []
        }
      )
    elsif result.failure?
      err, rate_limit = extract_sync_failure(result.failure)
      Integrations::MergeIntegrationSyncJobStatusCommand.call(
        job_id: job_id,
        attrs: {
          'status' => 'failed',
          'error' => err,
          'rate_limit' => rate_limit,
          'results' => []
        }
      )
    else
      outcome = result.value!
      Integrations::MergeIntegrationSyncJobStatusCommand.call(
        job_id: job_id,
        attrs: {
          'status' => 'complete',
          'error' => nil,
          'rate_limit' => false,
          'results' => outcome['results'] || []
        }
      )
    end
  rescue StandardError => e
    Rails.logger.error "[IntegrationSyncJob] #{job_id}: #{e.class}: #{e.message}"
    cancelled = Integrations::SyncJobCancellation.requested?(job_id)
    Integrations::SyncJobCancellation.clear!(job_id)
    if cancelled
      Integrations::MergeIntegrationSyncJobStatusCommand.call(
        job_id: job_id,
        attrs: {
          'status' => 'cancelled',
          'error' => nil,
          'rate_limit' => false,
          'results' => []
        }
      )
    else
      Integrations::MergeIntegrationSyncJobStatusCommand.call(
        job_id: job_id,
        attrs: {
          'status' => 'failed',
          'error' => e.message.to_s,
          'rate_limit' => false,
          'results' => []
        }
      )
    end
  end

  private

  def extract_sync_failure(fv)
    return [fv.to_s, false] unless fv.is_a?(Hash)

    errs = fv[:errors]
    if errs.is_a?(Hash)
      msg = errs[:message] || errs['message'] || fv[:type]
      rate = errs[:rate_limit] == true || errs['rate_limit'] == true
      [msg.to_s, rate]
    else
      [(fv[:message] || errs || fv[:type]).to_s, false]
    end
  end
end
