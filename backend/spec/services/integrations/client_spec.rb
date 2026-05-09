# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Client do
  around do |example|
    described_class.instance_variable_set(:@grpc_stubs_by_host, {})
    example.run
    described_class.instance_variable_set(:@grpc_stubs_by_host, {})
  end

  describe '.fetch_orcid_achievements' do
    it 'returns nil when orcid is blank' do
      expect(described_class.fetch_orcid_achievements('  ', cancel_proc: nil)).to be_nil
    end
  end

  describe '.fetch_open_alex_achievements' do
    it 'returns nil when openalex id is blank' do
      expect(described_class.fetch_open_alex_achievements('', cancel_proc: nil)).to be_nil
    end
  end

  describe '.unary_rpc' do
    it 'invokes unary RPC directly when cancel_proc is nil' do
      stub = double('grpc_stub')
      expect(stub).to receive(:sync_all_achievements).with(instance_of(Integrations::SyncRequest), deadline: kind_of(Time)).and_return(:grpc_ok)

      result = described_class.unary_rpc(
        stub,
        :sync_all_achievements,
        Integrations::SyncRequest.new(provider: 'orcid'),
        nil,
        deadline: Time.now + 120
      )

      expect(result).to eq(:grpc_ok)
    end
  end
end
