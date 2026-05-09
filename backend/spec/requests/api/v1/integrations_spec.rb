# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'api/v1/integrations', type: :request do
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /api/v1/integrations/save_achievements' do
    context 'with empty arrays' do
      it 'returns 200 with saved_count 0' do
        allow(Integrations::PersistSyncResultsService).to receive(:call).and_return({ saved_count: 0 })

        post '/api/v1/integrations/save_achievements',
             params: { achievements: [], researcher_dev_data: [], team_dev_data: [] }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['saved_count']).to eq(0)
        expect(json['message']).to include('0')
      end
    end

    context 'with achievement data' do
      let(:achievements) do
        [
          {
            researcher_id: 1,
            title: 'Test Publication',
            external_id: 'doi:10.1234/test',
            achievement_type: 'publication'
          }
        ]
      end

      it 'calls PersistSyncResultsService and returns saved count' do
        allow(Integrations::PersistSyncResultsService).to receive(:call).and_return({ saved_count: 1 })

        post '/api/v1/integrations/save_achievements',
             params: { achievements: achievements }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['saved_count']).to eq(1)
        expect(json['message']).to include('1')
      end
    end

    context 'with missing parameters' do
      it 'uses empty arrays as defaults' do
        allow(Integrations::PersistSyncResultsService).to receive(:call)
          .with(achievements: [], researcher_dev_data: [], team_dev_data: [])
          .and_return({ saved_count: 0 })

        post '/api/v1/integrations/save_achievements',
             params: {}.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
