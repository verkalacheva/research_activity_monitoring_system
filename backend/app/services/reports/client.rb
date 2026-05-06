require 'grpc'

$LOAD_PATH.unshift(Rails.root.join('lib').to_s) unless $LOAD_PATH.include?(Rails.root.join('lib').to_s)

require 'grpc_reports/reports_pb'
require 'grpc_reports/reports_services_pb'

module Reports
  class Client
    @grpc_mx = Mutex.new
    @grpc_stub_host = {}

    def self.analytics_stub(host)
      @grpc_mx.synchronize do
        @grpc_stub_host[host] ||= GrpcReports::AnalyticsService::Stub.new(
          host,
          :this_channel_is_insecure,
          channel_args: ::ServiceGrpc::CHANNEL_ARGS
        )
      end
    end

    def self.generate(params)
      host = ENV.fetch('ANALYTICS_SERVICE_HOST', 'analytics:50051')
      stub = analytics_stub(host)
      
      request = GrpcReports::ReportRequest.new({
        report_type: params[:report_type].to_s,
        filters: params[:filters]&.map { |f| GrpcReports::Filter.new(f.transform_keys(&:to_sym)) } || [],
        sorts: params[:sorts]&.map { |s| GrpcReports::Sort.new(s.transform_keys(&:to_sym)) } || [],
        limit: params[:limit].to_i,
        offset: params[:offset].to_i,
        format: params[:format].to_s
      })
      
      stub.generate_report(request, deadline: Time.now + ::ServiceGrpc::DEADLINE_ANALYTICS)
    end
  end
end
