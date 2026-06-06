# frozen_string_literal: true

module Auth
  class RefreshCommand < BaseCommand
    def call(refresh_token:, request: nil)
      record = RefreshTokenService.find_active(refresh_token)
      return failure(:unauthorized, 'Invalid refresh token') unless record

      user = record.user
      return failure(:unauthorized, 'User inactive') unless user.is_active?

      RefreshTokenService.revoke(refresh_token)
      success(Auth::TokenResponseBuilder.build(user, request: request))
    end
  end
end
