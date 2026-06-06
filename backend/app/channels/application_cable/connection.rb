# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      token = request.params[:token].presence ||
              request.headers['Authorization'].to_s.delete_prefix('Bearer ').strip.presence
      payload = Auth::JwtService.decode(token)
      reject_unauthorized_connection unless payload

      user = User.active.find_by(id: payload[:sub])
      reject_unauthorized_connection unless user

      self.current_user = user
    end
  end
end
