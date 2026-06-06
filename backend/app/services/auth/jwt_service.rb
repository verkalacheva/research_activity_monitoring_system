# frozen_string_literal: true

module Auth
  class JwtService
    ALGORITHM = 'HS256'

    class << self
      def encode(user)
        payload = {
          sub: user.id,
          admin_id: user.admin_owner_id,
          exp: access_ttl.from_now.to_i,
          iat: Time.current.to_i
        }
        JWT.encode(payload, secret, ALGORITHM)
      end

      def decode(token)
        payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
        payload.with_indifferent_access
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      private

      def secret
        ENV.fetch('JWT_SECRET') { Rails.application.secret_key_base }
      end

      def access_ttl
        ENV.fetch('JWT_ACCESS_TTL_SECONDS', 3600).to_i.seconds
      end
    end
  end
end
