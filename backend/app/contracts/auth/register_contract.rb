# frozen_string_literal: true

module Auth
  class RegisterContract < BaseContract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
      required(:password_confirmation).filled(:string)
      optional(:full_name).maybe(:string)
    end

    rule(:email) do
      key.failure('invalid format') unless value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
    end

    rule(:password) do
      key.failure('must be at least 8 characters') if value.to_s.length < 8
    end

    rule(:password_confirmation, :password) do
      key.failure('must match password') if values[:password] != values[:password_confirmation]
    end
  end
end
