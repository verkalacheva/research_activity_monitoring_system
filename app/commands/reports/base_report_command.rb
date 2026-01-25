module Reports
  class BaseReportCommand < BaseCommand
    def call(params)
      # Extract filters dynamically from all top-level params that are not "system" params
      extracted_filters = extract_filters(params)
      
      report_params = params.dup
      # Prioritize filters passed in the dedicated array, but append extracted ones
      report_params[:filters] = (report_params[:filters] || []) + extracted_filters
      
      contract = Reports::GenerateContract.new.call(report_params)
      return failure(:validation_error, contract.errors.to_h) if contract.failure?

      begin
        input = contract.to_h
        grpc_params = input.merge(format: input[:report_format] || input[:format])
        
        Rails.logger.info "Calling Analytics Service for #{input[:report_type]}"
        response = Reports::Client.generate(grpc_params)
        
        data_content = response.data.to_s
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
          column_totals: response.column_totals ? response.column_totals.to_h : {}
        }

        # Broadcast to ActionCable
        ActionCable.server.broadcast("reports_channel", result)

        success(result)
      rescue GRPC::BadStatus => e
        Rails.logger.error "GRPC Error: #{e.message}"
        failure(:grpc_error, "Analytics service error: #{e.message}")
      rescue JSON::ParserError => e
        Rails.logger.error "JSON Parse Error: #{e.message}. Content: #{data_content.inspect}"
        failure(:internal_error, "Invalid JSON from analytics service")
      rescue => e
        Rails.logger.error "Internal Error in #{self.class.name}: #{e.message}\n#{e.backtrace.join("\n")}"
        failure(:internal_error, "Internal error: #{e.message}")
      end
    end

    def self.id
      raise NotImplementedError
    end

    private

    SYSTEM_PARAMS = [:report_type, :report_format, :limit, :offset, :sorts, :format, :controller, :action, :filters].freeze

    def extract_filters(params)
      params.map do |key, value|
        next if SYSTEM_PARAMS.include?(key.to_sym)
        next if key.to_s.end_with?('_operator')
        next if value.blank?

        operator = params["#{key}_operator"] || (value.is_a?(Array) ? 'in' : 'eq')
        
        {
          field: key.to_s,
          operator: operator,
          value: value.is_a?(Array) ? value.join(',') : value.to_s
        }
      end.compact
    end
  end
end

