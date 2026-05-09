# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/sync_results', type: :request do
  # Очищаем Redis-хранилище перед каждым тестом
  before { Integrations::PendingSyncResultsStore.clear! }

  # ---------------------------------------------------------------------------
  # GET /api/v1/sync_results
  # ---------------------------------------------------------------------------
  path '/api/v1/sync_results' do
    get('show pending sync results') do
      tags 'SyncResults'

      context 'когда результатов нет' do
        response(200, 'successful — пустой массив') do
          schema load_schema(:models, :sync_results, :show)

          run_test!(nil, :aggregate_failures) do |response|
            data = response.parsed_body

            expect(data).to have_key('results')
            expect(data['results']).to eq([])
          end
        end
      end

      context 'когда результаты записаны заранее' do
        before do
          Integrations::PendingSyncResultsStore.write_array(
            [{ 'job_id' => 'abc-123', 'status' => 'done' }]
          )
        end

        response(200, 'successful — возвращает сохранённые результаты') do
          schema load_schema(:models, :sync_results, :show)

          run_test!(nil, :aggregate_failures) do |response|
            data = response.parsed_body

            expect(data['results'].size).to eq(1)
            expect(data['results'].first['job_id']).to eq('abc-123')
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/sync_results
  # ---------------------------------------------------------------------------
  path '/api/v1/sync_results' do
    put('update pending sync results') do
      tags 'SyncResults'
      consumes 'application/json'

      parameter name: :sync_results_body, in: :body, schema: {
        type: :object,
        properties: {
          results: {
            type: :array,
            items: { type: :object }
          }
        }
      }

      let(:sync_results_body) do
        {
          results: [
            { 'job_id' => 'job-1', 'status' => 'done', 'saved_count' => 5 },
            { 'job_id' => 'job-2', 'status' => 'error', 'error' => 'timeout' }
          ]
        }
      end

      response(200, 'successful — результаты сохранены') do
        schema load_schema(:models, :sync_results, :ok)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['ok']).to be true

          stored = Integrations::PendingSyncResultsStore.read_array
          expect(stored.size).to eq(2)
          expect(stored.first['job_id']).to eq('job-1')
        end
      end

      response(200, 'successful — пустой массив сбрасывает очередь') do
        schema load_schema(:models, :sync_results, :ok)

        before do
          Integrations::PendingSyncResultsStore.write_array([{ 'job_id' => 'old' }])
        end

        let(:sync_results_body) { { results: [] } }

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['ok']).to be true
          expect(Integrations::PendingSyncResultsStore.read_array).to eq([])
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/sync_results
  # ---------------------------------------------------------------------------
  path '/api/v1/sync_results' do
    delete('clear pending sync results') do
      tags 'SyncResults'

      before do
        Integrations::PendingSyncResultsStore.write_array(
          [{ 'job_id' => 'x' }, { 'job_id' => 'y' }]
        )
      end

      response(200, 'successful — очередь очищена') do
        schema load_schema(:models, :sync_results, :ok)

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['ok']).to be true
          expect(Integrations::PendingSyncResultsStore.read_array).to eq([])
        end
      end
    end
  end
end
