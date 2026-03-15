require 'grpc'

$LOAD_PATH.unshift(Rails.root.join('lib').to_s) unless $LOAD_PATH.include?(Rails.root.join('lib').to_s)

require 'grpc_integrations/integrations_pb'
require 'grpc_integrations/integrations_services_pb'

module Integrations
  class Client
    def self.sync_all(provider = 'orcid')
      host = ENV.fetch('INTEGRATION_SERVICE_HOST', 'integration:50052')
      stub = ::GrpcIntegrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)
      
      request = ::GrpcIntegrations::SyncRequest.new(provider: provider)
      stub.sync_all_achievements(request)
    end
  end
end

