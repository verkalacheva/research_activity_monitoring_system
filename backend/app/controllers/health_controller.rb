# frozen_string_literal: true

class HealthController < ActionController::API
  def live
    head :ok
  end

  def ready
    errors = []

    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
    rescue StandardError => e
      errors << { check: "database", error: e.class.name }
    end

    begin
      Sidekiq.redis { |c| c.ping }
    rescue StandardError => e
      errors << { check: "redis", error: e.class.name }
    end

    if errors.empty?
      head :ok
    else
      render json: { status: "unready", errors: }, status: :service_unavailable
    end
  end
end
