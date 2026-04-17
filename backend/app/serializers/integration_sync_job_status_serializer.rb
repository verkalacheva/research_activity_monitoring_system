# frozen_string_literal: true

# Полное состояние задачи синхронизации (Redis + ответ GET /integration_sync_jobs/:id).
class IntegrationSyncJobStatusSerializer < BaseSerializer
  def to_h
    h = object.is_a?(Hash) ? object.deep_stringify_keys : {}
    results = Array(h['results']).map { |row| SyncPreviewResultRowSerializer.new(row).to_h }

    {
      'status' => h['status'],
      'error' => h['error'],
      'rate_limit' => truthy?(h['rate_limit']),
      'results' => results
    }
  end

  private

  def truthy?(val)
    val == true || val.to_s == 'true'
  end
end
