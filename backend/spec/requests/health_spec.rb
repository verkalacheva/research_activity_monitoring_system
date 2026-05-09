# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health', type: :request do
  describe 'GET /health/live' do
    it 'returns 200 OK' do
      get '/health/live'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /health' do
    it 'returns 200 OK' do
      get '/health'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /health/ready' do
    context 'when database and redis are available' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow(Sidekiq).to receive(:redis).and_yield(double(ping: 'PONG'))
      end

      it 'returns 200 OK' do
        get '/health/ready'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when database is unavailable' do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'connection refused')
      end

      it 'returns 503 service unavailable' do
        get '/health/ready'
        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('unready')
        expect(json['errors']).not_to be_empty
      end
    end

    context 'when redis is unavailable' do
      before do
        allow(Sidekiq).to receive(:redis).and_raise(Redis::CannotConnectError, 'connection refused')
      end

      it 'returns 503 service unavailable' do
        get '/health/ready'
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
