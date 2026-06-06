# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::ExecuteGenerateInteractor do
  let(:valid_input) do
    {
      report_type: 'researchers',
      filters: [],
      sorts: [],
      limit: 10,
      offset: 0,
      report_format: 'json'
    }
  end

  describe '.call' do
    it 'parses JSON payload, broadcasts and succeeds' do
      admin = create(:user, role: 'admin')
      Current.user = admin

      response = double(
        'grpc_response',
        data: '{"items":[]}',
        format: 'json',
        total_count: 0,
        column_totals: nil
      )
      allow(Reports::Client).to receive(:generate).and_return(response)
      allow(ActionCable.server).to receive(:broadcast)

      result = described_class.call(input: valid_input)

      expect(result).to be_success
      expect(result.value![:data]).to eq({ 'items' => [] })
      expect(ActionCable.server).to have_received(:broadcast).with(
        "reports_channel:#{admin.id}",
        hash_including(report_type: 'researchers', format: 'json', total_count: 0, admin_id: admin.id)
      )
    ensure
      Current.reset
    end

    it 'returns failure on GRPC error without broadcasting' do
      allow(Reports::Client).to receive(:generate).and_raise(GRPC::Unavailable.new('deadline exceeded'))
      allow(ActionCable.server).to receive(:broadcast)

      result = described_class.call(input: valid_input)

      expect(result).to be_failure
      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it 'returns failure when analytics returns invalid JSON' do
      response = double('grpc_response', data: 'not-json{', format: 'json', total_count: 0, column_totals: nil)
      allow(Reports::Client).to receive(:generate).and_return(response)
      allow(ActionCable.server).to receive(:broadcast)

      result = described_class.call(input: valid_input)

      expect(result).to be_failure
      expect(ActionCable.server).not_to have_received(:broadcast)
    end
  end
end
