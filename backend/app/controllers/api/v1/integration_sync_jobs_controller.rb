# frozen_string_literal: true

module Api
  module V1
    class IntegrationSyncJobsController < BaseController
      wrap_parameters false

      # POST /api/v1/integration_sync_jobs
      def create
        job_id = SecureRandom.uuid
        # Sidekiq strict_args: только «родные» JSON-типы, без HashWithIndifferentAccess.
        payload = JSON.parse(job_params.compact.to_json)

        queued = Integrations::MergeIntegrationSyncJobStatusCommand.call(
          job_id: job_id,
          attrs: {
            'admin_id' => Current.admin_id,
            'status' => 'queued',
            'error' => nil,
            'rate_limit' => false,
            'results' => []
          }
        )
        return render_result(queued) if queued.failure?

        IntegrationSyncJob.perform_async(job_id, Current.admin_id, payload)

        render_result(
          Integrations::IntegrationSyncJobCreateResponseCommand.call(job_id: job_id),
          status_on_success: :accepted
        )
      end

      # GET /api/v1/integration_sync_jobs/:id
      def show
        render_result(Integrations::ReadIntegrationSyncJobStatusCommand.call(job_id: params[:id]))
      end

      # DELETE /api/v1/integration_sync_jobs/:id — запрос отмены фоновой задачи (кнопка «Стоп»).
      def destroy
        jid = params[:id].to_s
        unless jid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          return render json: { error: 'invalid job_id' }, status: :unprocessable_entity
        end

        status = Integrations::ReadIntegrationSyncJobStatusCommand.call(job_id: jid)
        return render_result(status) if status.failure?

        Integrations::SyncJobCancellation.request!(jid)
        head :accepted
      end

      private

      def job_params
        params.permit(:provider, :researcher_id, :team_id, :scope, :url, :llm_provider)
      end
    end
  end
end
