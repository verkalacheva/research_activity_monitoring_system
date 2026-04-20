# frozen_string_literal: true

module Integrations
  # Очередь результатов предпросмотра синхронизации в Redis (колокольчик + SyncPreviewDialog).
  # Формат значения — JSON-массив записей в том же виде, что и PUT /api/v1/sync_results.
  class PendingSyncResultsStore
    REDIS_KEY = 'sync_pending_results'
    TTL = 7 * 24 * 60 * 60 # 7 days

    class << self
      def read_array
        raw = redis.get(REDIS_KEY)
        return [] if raw.blank?

        parsed = JSON.parse(raw)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        []
      end

      def write_array(arr)
        redis.setex(REDIS_KEY, TTL, Array(arr).to_json)
      end

      def clear!
        redis.del(REDIS_KEY)
      end

      # Добавляет одну запись ежедневной синхронизации, заменяя предыдущую с тем же provider.
      def replace_daily_sync_entry(entry)
        arr = read_array
        arr.reject! { |e| e.is_a?(Hash) && e['provider'].to_s == 'daily_sync' }
        arr << entry
        write_array(arr)
      end

      private

      def redis
        @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'))
      end
    end
  end
end
