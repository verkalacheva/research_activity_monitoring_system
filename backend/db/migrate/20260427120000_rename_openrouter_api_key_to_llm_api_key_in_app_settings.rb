# frozen_string_literal: true

# Перенос значения openrouter_api_key -> llm_api_key (EAV app_settings, уникальный key).
class RenameOpenrouterApiKeyToLlmApiKeyInAppSettings < ActiveRecord::Migration[7.0]
  class AppSetting < ActiveRecord::Base
    self.table_name = 'app_settings'
  end

  def up
    return unless table_exists?(:app_settings)

    old = AppSetting.find_by(key: 'openrouter_api_key')
    return if old.nil?

    if (existing = AppSetting.find_by(key: 'llm_api_key'))
      if existing.value.to_s.strip.empty? && old.value.to_s.strip.present?
        existing.update_columns(value: old.value, updated_at: Time.current)
      end
      old.delete
    else
      old.update_columns(key: 'llm_api_key', updated_at: Time.current)
    end
  end

  def down
    return unless table_exists?(:app_settings)

    cur = AppSetting.find_by(key: 'llm_api_key')
    return if cur.nil?
    return if AppSetting.exists?(key: 'openrouter_api_key')

    cur.update_columns(key: 'openrouter_api_key', updated_at: Time.current)
  end
end
