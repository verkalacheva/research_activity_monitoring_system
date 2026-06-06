# frozen_string_literal: true

module Reports
  # Вызов analytics по gRPC, разбор ответа и broadcast в ActionCable.
  class ExecuteGenerateInteractor < BaseInteractor
    def call(input:)
      data_content = +''
      input = input.deep_symbolize_keys
      grpc_params = input.merge(format: input[:report_format] || input[:format])

      Rails.logger.info "Calling Analytics Service for #{input[:report_type]}"
      response = Reports::Client.generate(grpc_params)

      data_content = response.data.to_s.dup.force_encoding('UTF-8')
      parsed_data = if response.format == 'json'
                      data_content.strip.empty? ? {} : JSON.parse(data_content)
                    else
                      data_content
                    end

      result = {
        report_type: input[:report_type],
        data: parsed_data,
        format: response.format.to_s,
        total_count: response.total_count.to_i,
        column_totals: response.column_totals ? response.column_totals.to_h : {},
        admin_id: Current.admin_id
      }

      return failure(:forbidden, 'admin context required') if Current.admin_id.blank?

      ActionCable.server.broadcast("reports_channel:#{Current.admin_id}", result)

      success(result)
    rescue GRPC::BadStatus => e
      Rails.logger.error "GRPC Error: #{e.message}"
      failure(:grpc_error, "Analytics service error: #{e.message}")
    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parse Error: #{e.message}. Content: #{data_content.inspect}"
      failure(:internal_error, 'Invalid JSON from analytics service')
    rescue StandardError => e
      Rails.logger.error "Internal Error in ExecuteGenerateInteractor: #{e.message}\n#{e.backtrace.join("\n")}"
      failure(:internal_error, "Internal error: #{e.message}")
    end
  end
end
