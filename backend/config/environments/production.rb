# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.active_storage.service = :local
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id] if config.respond_to?(:log_tags=)
  config.active_support.report_deprecations = false
  config.i18n.fallbacks = true

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")

  # SPA (Flutter web) может быть на другом origin, чем API; иначе /cable не апгрейдится.
  # Список через запятую: https://app.example.org,http://localhost:8080
  if (origins_raw = ENV["ACTION_CABLE_ALLOWED_ORIGINS"].presence)
    origins = origins_raw.split(",").map(&:strip).reject(&:empty?)
    if origins.any?
      config.action_cable.allowed_request_origins = origins
    end
  end
end
