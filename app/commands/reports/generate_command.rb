module Reports
  class GenerateCommand < BaseCommand
    def call(params)
      contract = Reports::GenerateContract.new.call(params)
      return failure(:validation_error, contract.errors.to_h) if contract.failure?

      # In a real app, this might be asynchronous
      # For now, we call the analytics service and then broadcast
      begin
        input = contract.to_h
        grpc_params = input.merge(format: input[:report_format])
        
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
        Rails.logger.error "Internal Error in GenerateCommand: #{e.message}\n#{e.backtrace.join("\n")}"
        failure(:internal_error, "Internal error: #{e.message}")
      end
    end
  end
end

