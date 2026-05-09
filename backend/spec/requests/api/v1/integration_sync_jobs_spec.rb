# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/integration_sync_jobs', type: :request do
  # ---------------------------------------------------------------------------
  # POST /api/v1/integration_sync_jobs
  # ---------------------------------------------------------------------------
  path '/api/v1/integration_sync_jobs' do
    post('create integration sync job') do
      tags 'IntegrationSyncJobs'
      consumes 'application/json'

      parameter name: :job_params, in: :body, schema: load_schema(:requests, :integration_sync_jobs, :create)

      let(:researcher) { create(:researcher, :with_openalex) }

      let(:job_params) do
        {
          provider:      'openalex',
          researcher_id: researcher.id,
          scope:         'publications'
        }
      end

      response(202, 'accepted — задача поставлена в очередь') do
        schema load_schema(:models, :integration_sync_jobs, :job)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['job_id']).to match(/\A[0-9a-f-]{36}\z/i)
          expect(data['status']).to eq('queued')
        end
      end

      response(202, 'accepted — минимальный запрос без параметров') do
        schema load_schema(:models, :integration_sync_jobs, :job)

        let(:job_params) { {} }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['status']).to eq('queued')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/integration_sync_jobs/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/integration_sync_jobs/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'UUID задачи'

    let(:job_id) do
      post '/api/v1/integration_sync_jobs', params: {}, as: :json
      JSON.parse(response.body)['job_id']
    end
    let(:id) { job_id }

    get('show integration sync job status') do
      tags 'IntegrationSyncJobs'

      response(200, 'successful — статус задачи') do
        schema load_schema(:models, :integration_sync_jobs, :job)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data).to have_key('status')
          expect(data['status']).to be_in(%w[queued running done cancelled error])
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/integration_sync_jobs/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/integration_sync_jobs/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'UUID задачи'

    delete('cancel integration sync job') do
      tags 'IntegrationSyncJobs'

      response(202, 'accepted — запрос на отмену отправлен') do
        let(:id) { SecureRandom.uuid }

        run_test! do
          expect(response.status).to eq(202)
        end
      end

      response(422, 'unprocessable entity — невалидный формат job_id') do
        schema load_schema(:shared, :error)

        let(:id) { 'not-a-uuid' }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(response.status).to eq(422)
          expect(data).to have_key('error')
        end
      end
    end
  end
end
