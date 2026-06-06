# frozen_string_literal: true

module Integrations
  # Очередь результатов предпросмотра синхронизации в Redis (колокольчик + SyncPreviewDialog).
  # Формат значения — JSON-массив записей в том же виде, что и PUT /api/v1/sync_results.
  class PendingSyncResultsStore
    REDIS_KEY_PREFIX = 'sync_pending_results'
    TTL = 7 * 24 * 60 * 60 # 7 days

    class << self
      def read_array(admin_id: Current.admin_id)
        raw = redis.get(redis_key(admin_id))
        return [] if raw.blank?

        parsed = JSON.parse(raw)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        []
      end

      def write_array(arr, admin_id: Current.admin_id)
        redis.setex(redis_key(admin_id), TTL, Array(arr).to_json)
      end

      def clear!(admin_id: Current.admin_id)
        redis.del(redis_key(admin_id))
      end

      # Добавляет одну запись ежедневной синхронизации, заменяя предыдущую с тем же provider.
      def replace_daily_sync_entry(entry, admin_id:)
        arr = read_array(admin_id: admin_id)
        arr.reject! { |e| e.is_a?(Hash) && e['provider'].to_s == 'daily_sync' }
        arr << entry
        write_array(arr, admin_id: admin_id)
      end

      def redis_key(admin_id)
        raise ArgumentError, 'admin_id required' if admin_id.blank?

        "#{REDIS_KEY_PREFIX}:#{admin_id}"
      end

      private

      def redis
        @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'))
      end
    end
  end
end
