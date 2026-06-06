module Api
  module V1
    class BaseController < ActionController::API
      include Dry::Monads[:result]
      include Authenticatable
      include TenantScopedHelpers

      def render_result(result, status_on_success: :ok)
        case result
        when Success
          render json: result.value!, status: status_on_success
        when Failure
          render_failure(result.failure)
        else
          render json: result, status: status_on_success
        end
      end

      private

      def render_failure(failure)
        case failure
        when Hash
          status = case failure[:type]
                   when :validation_error then :unprocessable_entity
                   when :not_found then :not_found
                   when :unauthorized then :unauthorized
                   when :forbidden then :forbidden
                   else :bad_request
                   end
          render json: {
            errors: failure[:errors] || failure[:message],
            type: failure[:type],
            message: failure[:message]
          }, status: status
        else
          render json: { error: failure }, status: :bad_request
        end
      end
    end
  end
end

