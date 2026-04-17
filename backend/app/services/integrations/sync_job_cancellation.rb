# frozen_string_literal: true

module Integrations
  # Клиент нажимает «Стоп» → DELETE /integration_sync_jobs/:id → флаг в Redis;
  # Sidekiq в cancel_proc читает флаг и вызывает op.cancel() на gRPC (краулер останавливается).
  class SyncJobCancellation
    PREFIX = 'integration_sync_job_cancel:'
    TTL = 24 * 60 * 60

    class << self
      def redis
        SyncJobStore.redis
      end

      def key(id)
        "#{PREFIX}#{id}"
      end

      def request!(job_id)
        return if job_id.blank?

        redis.setex(key(job_id), TTL, '1')
      end

      def requested?(job_id)
        job_id.present? && redis.get(key(job_id)).present?
      end

      def clear!(job_id)
        return if job_id.blank?

        redis.del(key(job_id))
      end
    end
  end
end
