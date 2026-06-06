# frozen_string_literal: true

module Auth
  class LoginContract < BaseContract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
    end
  end
end
