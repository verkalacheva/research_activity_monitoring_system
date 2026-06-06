# frozen_string_literal: true

module Auth
  class TokenResponseBuilder
    def self.build(user, request: nil)
      access_token = JwtService.encode(user)
      refresh_raw, = RefreshTokenService.issue(
        user,
        user_agent: request&.user_agent,
        ip_address: request&.remote_ip
      )

      {
        user: user.as_auth_json,
        access_token: access_token,
        refresh_token: refresh_raw,
        expires_in: ENV.fetch('JWT_ACCESS_TTL_SECONDS', 3600).to_i
      }
    end
  end
end
