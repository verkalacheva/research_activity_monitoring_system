module Api
  module V1
    # Stores completed sync results in Redis so the notification bell
    # survives page reloads and browser restarts.
    class SyncResultsController < BaseController
      # Disable Rails wrap_parameters — we receive a plain { results: [...] } body.
      wrap_parameters false

      # GET /api/v1/sync_results
      def show
        render json: { results: Integrations::PendingSyncResultsStore.read_array }
      end

      # PUT /api/v1/sync_results
      def update
        # Use [] as default: an empty array is valid (clears pending results).
        results = params[:results] || []
        Integrations::PendingSyncResultsStore.write_array(results)
        render json: { ok: true }
      end

      # DELETE /api/v1/sync_results
      def destroy
        Integrations::PendingSyncResultsStore.clear!
        render json: { ok: true }
      end
    end
  end
end
