# frozen_string_literal: true

module Integrations
  class SyncPreviewCommand < BaseCommand
    def call(params)
      raw = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : params
      raw = raw.symbolize_keys
      @cancel_proc = raw[:cancel_proc].respond_to?(:call) ? raw[:cancel_proc] : -> { false }
      @params = normalize_params(raw.except(:cancel_proc))

      preview = SyncPreview::ExecuteInteractor.call(params: @params, cancel_proc: @cancel_proc)
      return preview if preview.failure?

      success(payload_success(preview.value!))
    rescue GRPC::BadStatus => e
      handle_grpc_error(e)
    end

    private

    def normalize_params(hash)
      ActionController::Parameters.new(hash)
    end

    def payload_success(results)
      rows = Array(results).map { |row| SyncPreviewResultRowSerializer.new(row).to_h }
      { 'results' => rows }
    end

    def handle_grpc_error(e)
      if e.code == GRPC::Core::StatusCodes::CANCELLED
        Rails.logger.info '[SyncPreviewCommand] gRPC cancelled'
        success(payload_success([]))
      else
        msg = e.message.to_s.force_encoding('UTF-8')
        Rails.logger.error "[SyncPreviewCommand] gRPC error (#{e.class}): #{msg}"
        failure(
          :service_unavailable,
          { message: msg, rate_limit: rate_limit_message?(msg) }
        )
      end
    end

    def rate_limit_message?(msg)
      lower = msg.downcase
      lower.include?('rate_limit') ||
        lower.include?('rate limit') ||
        lower.include?('429') ||
        lower.include?('quota') ||
        lower.include?('api rate limit exceeded')
    end
  end
end
