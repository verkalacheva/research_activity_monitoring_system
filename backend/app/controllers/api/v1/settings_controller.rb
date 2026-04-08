module Api
  module V1
    class SettingsController < BaseController
      ALLOWED_KEYS = %w[
        github_token
        openrouter_api_key
        tavily_api_key
        llm_model_name
        llm_provider
      ].freeze

      def show
        settings = AppSetting.where(key: ALLOWED_KEYS).each_with_object({}) do |s, hash|
          hash[s.key] = s.value
        end
        render json: { settings: settings }
      end

      def update
        settings_params = params.require(:settings).permit(*ALLOWED_KEYS).to_h
        updated = {}

        settings_params.each do |key, value|
          next unless ALLOWED_KEYS.include?(key)

          record = AppSetting.find_or_initialize_by(key: key)
          record.value = value.presence
          record.save!
          updated[key] = record.value
        end

        render json: { settings: updated }
      rescue ActiveRecord::RecordInvalid => e
        render_failure({ type: :validation_error, message: e.message })
      end
    end
  end
end
