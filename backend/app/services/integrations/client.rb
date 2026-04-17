# frozen_string_literal: true

module Integrations
  class Client
    CANCELLED = GRPC::Core::StatusCodes::CANCELLED

    def self.sync_all(provider = 'orcid', cancel_proc: nil)
      return nil unless ::Integrations::SyncRequest

      host = ENV.fetch('INTEGRATION_SERVICE_HOST', 'integration:50052')
      stub = ::Integrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)

      request = ::Integrations::SyncRequest.new(provider: provider)
      unary_rpc(stub, :sync_all_achievements, request, cancel_proc)
    end

    def self.fetch_orcid_achievements(orcid_id, cancel_proc: nil)
      return nil unless ::Integrations::OrcidRequest
      return nil if orcid_id.to_s.strip.empty?

      host = ENV.fetch('INTEGRATION_SERVICE_HOST', 'integration:50052')
      stub = ::Integrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)
      request = ::Integrations::OrcidRequest.new(orcid_id: orcid_id.to_s)
      unary_rpc(stub, :fetch_orcid_achievements, request, cancel_proc)
    end

    def self.fetch_open_alex_achievements(openalex_id, cancel_proc: nil)
      return nil unless ::Integrations::OpenAlexRequest
      return nil if openalex_id.to_s.strip.empty?

      host = ENV.fetch('INTEGRATION_SERVICE_HOST', 'integration:50052')
      stub = ::Integrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)
      request = ::Integrations::OpenAlexRequest.new(openalex_id: openalex_id.to_s)
      unary_rpc(stub, :fetch_open_alex_achievements, request, cancel_proc)
    end

    def self.crawl(url, researcher_id, researcher_name = nil, auto_search = false, llm_provider = nil, github_username = nil, cancel_proc: nil)
      return nil unless ::Integrations::CrawlRequest

      host = ENV.fetch('CRAWLER_SERVICE_HOST', 'crawler:50053')
      stub = ::Integrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)

      resolved_provider = llm_provider.presence || AppSetting.get('llm_provider_name').presence || ''
      resolved_model    = AppSetting.get('llm_model_name').presence || ''

      params = {
        url: url.to_s,
        researcher_id: researcher_id.to_i,
        researcher_name: researcher_name.to_s,
        auto_search: auto_search,
        llm_provider: resolved_provider,
        llm_model: resolved_model,
        github_username: github_username.to_s
      }

      request = ::Integrations::CrawlRequest.new(params)
      unary_rpc(stub, :crawl_achievements, request, cancel_proc)
    end

    # Метрики GitHub через integration_service (прямой GitHub API). Не использует CRAWLER_SERVICE_HOST.
    def self.github_dev_activity(github_username, researcher_id = nil, team_id = nil, cancel_proc: nil)
      return nil unless ::Integrations::DevActivityRequest

      host = ENV.fetch('INTEGRATION_SERVICE_HOST', 'integration:50052')
      stub = ::Integrations::IntegrationService::Stub.new(host, :this_channel_is_insecure)

      params = {
        github_username: github_username.to_s,
        researcher_id: researcher_id.to_i,
        team_id: team_id.to_i
      }

      request = ::Integrations::DevActivityRequest.new(params)
      unary_rpc(stub, :crawl_dev_activity, request, cancel_proc)
    end

    # Runs a unary RPC; when cancel_proc returns true, calls Operation#cancel (client disconnect).
    def self.unary_rpc(stub, rpc_name, request_msg, cancel_proc)
      return stub.send(rpc_name, request_msg) unless cancel_proc

      op = stub.send(rpc_name, request_msg, return_op: true)
      worker = Thread.new do
        begin
          op.execute
        rescue GRPC::Cancelled
          # op.cancel — нормальный исход, поток не должен падать с report_on_exception.
          nil
        rescue GRPC::BadStatus => e
          # На случай отмены без отдельного класса Cancelled в иерархии.
          e.code == CANCELLED ? nil : raise(e)
        end
      end
      while worker.alive?
        if cancel_proc.call
          begin
            op.cancel
          rescue StandardError
            nil
          end
          break
        end
        sleep 0.15
      end
      worker.join
      worker.value
    rescue GRPC::Cancelled
      nil
    rescue GRPC::BadStatus => e
      return nil if e.code == CANCELLED
      raise
    end
  end
end
