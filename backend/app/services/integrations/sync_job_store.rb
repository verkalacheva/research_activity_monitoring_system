# frozen_string_literal: true

module Integrations
  # Состояние фоновой задачи синхронизации (Sidekiq) для опроса с фронтенда.
  class SyncJobStore
    PREFIX = 'integration_sync_job:'
    TTL = 24 * 60 * 60

    def self.redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
    end

    def self.key(id)
      "#{PREFIX}#{id}"
    end

    def self.write!(id, hash)
      redis.setex(key(id), TTL, hash.stringify_keys.to_json)
    end

    def self.read(id)
      raw = redis.get(key(id))
      raw.present? ? JSON.parse(raw) : nil
    end
  end
end
