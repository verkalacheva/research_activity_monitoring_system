# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/reports', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/reports/selectors
  # ---------------------------------------------------------------------------
  path '/api/v1/reports/selectors' do
    get('reports selectors — список доступных типов отчётов') do
      tags 'Reports'

      response(200, 'successful') do
        schema load_schema(:models, :reports, :selectors)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data).to have_key('report_types')
          expect(data['report_types']).to be_an(Array)
          expect(data['report_types'].size).to be >= 4

          ids = data['report_types'].map { |t| t['id'] }
          expect(ids).to include(
            'researchers_report',
            'teams',
            'dev_teams_report',
            'dev_researchers_report'
          )
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/reports/generate
  # ---------------------------------------------------------------------------
  path '/api/v1/reports/generate' do
    post('generate report') do
      tags 'Reports'
      consumes 'application/json'

      parameter name: :report_params, in: :body, schema: load_schema(:requests, :reports, :generate)

      let!(:researcher1) { create(:researcher) }
      let!(:researcher2) { create(:researcher) }

      # Stub gRPC to analytics service — not running in test environment
      before do
        grpc_response = double(
          'GrpcResponse',
          data: '[{"id":1}]',
          format: 'json',
          total_count: 1,
          column_totals: nil
        )
        allow(Reports::Client).to receive(:generate).and_return(grpc_response)
        allow(ActionCable.server).to receive(:broadcast)
      end

      context 'отчёт по исследователям' do
        let(:report_params) { { report_type: 'researchers_report', report_format: 'json' } }

        response(200, 'successful — список исследователей') do
          run_test!(nil, :aggregate_failures) do |response|
            data = response.parsed_body

            expect(response.status).to eq(200)
            expect(data).to be_an(Array).or have_key('data')
          end
        end
      end

      context 'отчёт по командам' do
        let!(:team1) { create(:team) }
        let!(:team2) { create(:team) }

        let(:report_params) { { report_type: 'teams', report_format: 'json' } }

        response(200, 'successful — список команд') do
          run_test!(nil, :aggregate_failures) do |response|
            expect(response.status).to eq(200)
          end
        end
      end

      context 'dashboard overview' do
        let(:report_params) { { report_type: 'dashboard_overview', report_format: 'json' } }

        response(200, 'successful — дашборд') do
          run_test! do |response|
            expect(response.status).to eq(200)
          end
        end
      end

      context 'неизвестный тип отчёта' do
        let(:report_params) { { report_type: 'nonexistent_report', report_format: 'json' } }

        response(200, 'successful — GenerateCommand фолбэк') do
          run_test! do |response|
            expect(response.status).to be_in([200, 422])
          end
        end
      end

      context 'отчёт по dev-активности команд' do
        let!(:team) { create(:team) }

        let(:report_params) { { report_type: 'dev_teams_report', report_format: 'json' } }

        response(200, 'successful — dev команды') do
          run_test! do |response|
            expect(response.status).to eq(200)
          end
        end
      end

      context 'отчёт по dev-активности исследователей' do
        let(:report_params) { { report_type: 'dev_researchers_report', report_format: 'json' } }

        response(200, 'successful — dev исследователи') do
          run_test! do |response|
            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
