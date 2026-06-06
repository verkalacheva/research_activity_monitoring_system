# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: %i[register login refresh]

      def register
        result = Auth::RegisterCommand.call(register_params.to_h)
        if result.success?
          render json: Auth::TokenResponseBuilder.build(result.value!, request: request), status: :created
        else
          render_result(result)
        end
      end

      def login
        result = Auth::LoginCommand.call(login_params.to_h)
        if result.success?
          render json: Auth::TokenResponseBuilder.build(result.value!, request: request)
        else
          render_result(result)
        end
      end

      def me
        render json: { user: current_user.as_auth_json }
      end

      def refresh
        token = params[:refresh_token].to_s.presence
        return render_failure({ type: :bad_request, message: 'refresh_token required' }) if token.blank?

        result = Auth::RefreshCommand.call(refresh_token: token, request: request)
        if result.success?
          render json: result.value!
        else
          render_result(result)
        end
      end

      def logout
        token = params[:refresh_token].to_s.presence
        Auth::RefreshTokenService.revoke(token) if token.present?
        head :no_content
      end

      private

      def register_params
        params.require(:user).permit(:email, :password, :password_confirmation, :full_name)
      end

      def login_params
        params.require(:user).permit(:email, :password)
      end
    end
  end
end
