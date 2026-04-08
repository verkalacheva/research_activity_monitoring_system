require 'grpc'

# В Rails development константы могут сбрасываться. 
# Мы добавляем lib в load_path, если его там нет, и используем require.
$LOAD_PATH.unshift(Rails.root.join('lib').to_s) unless $LOAD_PATH.include?(Rails.root.join('lib').to_s)

require 'grpc_reports/reports_pb'
require 'grpc_reports/reports_services_pb'

module Reports
  class Client
    def self.generate(params)
      # Use the service name from the docker-compose.yml
      host = ENV.fetch('ANALYTICS_SERVICE_HOST', 'analytics:50051')
      stub = GrpcReports::AnalyticsService::Stub.new(host, :this_channel_is_insecure)
      
      # Protobuf 4.x expects hashes with symbol keys
      request = GrpcReports::ReportRequest.new({
        report_type: params[:report_type].to_s,
        filters: params[:filters]&.map { |f| GrpcReports::Filter.new(f.transform_keys(&:to_sym)) } || [],
        sorts: params[:sorts]&.map { |s| GrpcReports::Sort.new(s.transform_keys(&:to_sym)) } || [],
        limit: params[:limit].to_i,
        offset: params[:offset].to_i,
        format: params[:format].to_s
      })
      
      stub.generate_report(request)
    end
  end
end
