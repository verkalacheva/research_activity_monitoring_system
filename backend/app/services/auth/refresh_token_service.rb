# frozen_string_literal: true

module Auth
  class RefreshTokenService
    class << self
      def issue(user, user_agent: nil, ip_address: nil)
        raw = SecureRandom.urlsafe_base64(32)
        record = user.refresh_tokens.create!(
          token_digest: digest(raw),
          expires_at: refresh_ttl.from_now,
          user_agent: user_agent,
          ip_address: ip_address
        )
        [raw, record]
      end

      def find_active(raw)
        RefreshToken.active.find_by(token_digest: digest(raw))
      end

      def revoke(raw)
        find_active(raw)&.revoke!
      end

      def revoke_all(user)
        user.refresh_tokens.active.find_each(&:revoke!)
      end

      private

      def digest(raw)
        Digest::SHA256.hexdigest(raw)
      end

      def refresh_ttl
        ENV.fetch('JWT_REFRESH_TTL_DAYS', 30).to_i.days
      end
    end
  end
end
