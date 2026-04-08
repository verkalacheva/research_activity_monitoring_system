module Api
  module V1
    # Stores completed sync results in Redis so the notification bell
    # survives page reloads and browser restarts.
    class SyncResultsController < BaseController
      REDIS_KEY = 'sync_pending_results'.freeze
      TTL       = 7 * 24 * 60 * 60  # 7 days

      # Disable Rails wrap_parameters — we receive a plain { results: [...] } body.
      wrap_parameters false

      # GET /api/v1/sync_results
      def show
        raw = redis.get(REDIS_KEY)
        render json: { results: raw ? JSON.parse(raw) : [] }
      end

      # PUT /api/v1/sync_results
      def update
        # Use [] as default: an empty array is valid (clears pending results).
        results = params[:results] || []
        redis.setex(REDIS_KEY, TTL, results.to_json)
        render json: { ok: true }
      end

      # DELETE /api/v1/sync_results
      def destroy
        redis.del(REDIS_KEY)
        render json: { ok: true }
      end

      private

      def redis
        @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'))
      end
    end
  end
end
