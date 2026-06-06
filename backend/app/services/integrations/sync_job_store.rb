# frozen_string_literal: true

module Integrations
  # Состояние фоновой задачи синхронизации (Sidekiq) для опроса с фронтенда.
  # Ключ и ActionCable-стрим включают admin_id, чтобы данные tenant не пересекались.
  class SyncJobStore
    PREFIX = 'integration_sync_job:'
    TTL = 24 * 60 * 60

    def self.redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
    end

    def self.key(admin_id:, job_id:)
      "#{PREFIX}#{admin_id}:#{job_id}"
    end

    def self.cable_stream(admin_id:, job_id:)
      key(admin_id: admin_id, job_id: job_id)
    end

    def self.write!(admin_id:, job_id:, hash:)
      payload = hash.stringify_keys.merge('admin_id' => admin_id.to_s)
      redis.setex(key(admin_id: admin_id, job_id: job_id), TTL, payload.to_json)
    end

    def self.read(admin_id:, job_id:)
      raw = redis.get(key(admin_id: admin_id, job_id: job_id))
      raw.present? ? JSON.parse(raw) : nil
    end
  end
end
