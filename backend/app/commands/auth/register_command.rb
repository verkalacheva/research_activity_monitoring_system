# frozen_string_literal: true

module Auth
  class RegisterCommand < BaseCommand
    def call(params)
      validated = yield validate(RegisterContract, params)

      if User.exists?(email: validated[:email].downcase.strip)
        return failure(:validation_error, { email: ['has already been taken'] })
      end

      user = User.new(
        email: validated[:email],
        password: validated[:password],
        password_confirmation: validated[:password_confirmation],
        full_name: validated[:full_name]
      )

      User.transaction do
        user.save!
        TenantCatalogSeeder.seed!(user)
      end

      success(user)
    rescue ActiveRecord::RecordInvalid
      failure(:validation_error, user.errors.messages)
    end
  end
end
