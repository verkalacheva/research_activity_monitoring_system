# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    around_action :set_current_user
  end

  private

  def authenticate_user!
    token = bearer_token
    return render_unauthorized unless token

    payload = Auth::JwtService.decode(token)
    return render_unauthorized unless payload

    @current_user = User.active.find_by(id: payload[:sub])
    render_unauthorized unless @current_user
  end

  def set_current_user
    Current.user = @current_user
    yield
  ensure
    Current.reset
  end

  def current_user
    @current_user
  end

  def current_admin_id
    current_user&.admin_owner_id
  end

  def bearer_token
    header = request.headers['Authorization'].to_s
    return nil unless header.start_with?('Bearer ')

    header.delete_prefix('Bearer ').strip.presence
  end

  def render_unauthorized
    render_failure({ type: :unauthorized, message: 'Unauthorized' })
  end

  def render_forbidden
    render_failure({ type: :forbidden, message: 'Forbidden' })
  end
end
