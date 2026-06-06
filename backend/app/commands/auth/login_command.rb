# frozen_string_literal: true

module Auth
  class LoginCommand < BaseCommand
    def call(params)
      validated = yield validate(LoginContract, params)
      email = validated[:email].to_s.downcase.strip
      user = User.active.find_by(email: email)

      unless user&.authenticate(validated[:password])
        return failure(:unauthorized, 'Invalid email or password')
      end

      user.update_column(:last_sign_in_at, Time.current)
      success(user)
    end
  end
end
