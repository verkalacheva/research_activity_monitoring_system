# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenant isolation', type: :request do
  let!(:admin_a) { create(:user, email: 'admin-a@example.com') }
  let!(:admin_b) { create(:user, email: 'admin-b@example.com') }

  describe 'reports generate' do
    before do
      allow(ActionCable.server).to receive(:broadcast)
    end

    %w[teams researchers_report dashboard_overview dev_teams_report dev_researchers_report].each do |report_type|
      it "injects admin_id filter for #{report_type}" do
        captured = nil
        allow(Reports::Client).to receive(:generate) do |params|
          captured = params
          double(
            'GrpcResponse',
            data: report_type == 'dashboard_overview' ? '{}' : '[]',
            format: 'json',
            total_count: 0,
            column_totals: nil
          )
        end

        post '/api/v1/reports/generate',
             params: { report_type: report_type, report_format: 'json' },
             headers: json_auth_headers(admin_b),
             as: :json

        expect(response).to have_http_status(:ok)
        admin_filter = Array(captured[:filters]).find { |f| f[:field].to_s == 'admin_id' }
        expect(admin_filter).to include(field: 'admin_id', operator: 'eq', value: admin_b.id.to_s)
      end
    end
  end

  describe 'catalog show' do
    it 'returns 404 for another admin dev project criterion' do
      foreign = create(:dev_project_criterion, admin: admin_b)

      get "/api/v1/dev_project_criteria/#{foreign.id}", headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for another admin achievement type' do
      foreign = create(:achievement_type, admin: admin_b)

      get "/api/v1/achievement_types/#{foreign.id}", headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for another admin achievement status' do
      foreign = create(:achievement_status, admin: admin_b)

      get "/api/v1/achievement_statuses/#{foreign.id}", headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'catalog list' do
    it 'lists only current admin dev criteria' do
      create(:dev_project_criterion, admin: admin_a, title: 'Mine')
      create(:dev_project_criterion, admin: admin_b, title: 'Theirs')

      get '/api/v1/dev_project_criteria/list', headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:ok)
      titles = response.parsed_body.fetch('items').map { |i| i['title'] }
      expect(titles).to include('Mine')
      expect(titles).not_to include('Theirs')
    end
  end

  describe 'teams list' do
    it 'lists only current admin teams' do
      create(:team, admin: admin_a, title: 'Team A')
      create(:team, admin: admin_b, title: 'Team B')

      get '/api/v1/teams/list', headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      items = body['items'] || body
      titles = Array(items).map { |i| i['title'] }
      expect(titles).to include('Team A')
      expect(titles).not_to include('Team B')
    end
  end

  describe 'sync results store' do
    it 'reads pending sync results scoped to admin' do
      Integrations::PendingSyncResultsStore.write_array(
        [{ 'provider' => 'github', 'label' => 'B only' }],
        admin_id: admin_b.id
      )
      Integrations::PendingSyncResultsStore.write_array(
        [{ 'provider' => 'github', 'label' => 'A only' }],
        admin_id: admin_a.id
      )

      get '/api/v1/sync_results', headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:ok)
      labels = response.parsed_body.fetch('results').map { |r| r['label'] }
      expect(labels).to eq(['A only'])
    end
  end

  describe 'integration sync jobs' do
    it 'returns 404 when reading another admin job status' do
      job_id = SecureRandom.uuid
      Integrations::SyncJobStore.write!(
        admin_id: admin_b.id,
        job_id: job_id,
        hash: { 'status' => 'queued', 'error' => nil, 'results' => [] }
      )

      get "/api/v1/integration_sync_jobs/#{job_id}", headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when cancelling another admin job' do
      job_id = SecureRandom.uuid
      Integrations::SyncJobStore.write!(
        admin_id: admin_b.id,
        job_id: job_id,
        hash: { 'status' => 'running', 'error' => nil, 'results' => [] }
      )

      delete "/api/v1/integration_sync_jobs/#{job_id}", headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'achievements create' do
    it 'rejects catalog ids from another admin' do
      foreign_type = create(:achievement_type, admin: admin_b)
      foreign_status = create(:achievement_status, admin: admin_b)
      foreign_result = create(:achievement_result, admin: admin_b)
      foreign_participation = create(:achievement_participation, admin: admin_b)

      post '/api/v1/achievements',
           params: {
             achievement: {
               achievement_type_id: foreign_type.id,
               achievement_status_id: foreign_status.id,
               achievement_result_id: foreign_result.id,
               achievement_participation_id: foreign_participation.id
             }
           },
           headers: json_auth_headers(admin_a),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'save_achievements' do
    it 'does not save achievements for another admin researcher' do
      foreign_researcher = create(:researcher, admin: admin_b)

      post '/api/v1/integrations/save_achievements',
           params: {
             achievements: [{
               researcher_id: foreign_researcher.id,
               type: 'Статья',
               title: 'Foreign paper',
               description: 'x',
               url: 'http://example.com',
               date: '2024-01-01',
               author_count: 1
             }]
           },
           headers: json_auth_headers(admin_a),
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['saved_count']).to eq(0)
    end
  end

  describe 'achievements list' do
    it 'lists only current admin achievements' do
      type_a = create(:achievement_type, admin: admin_a, title: 'Type A')
      type_b = create(:achievement_type, admin: admin_b, title: 'Type B')
      status = create(:achievement_status, admin: admin_a)
      result = create(:achievement_result, admin: admin_a)
      participation = create(:achievement_participation, admin: admin_a)
      researcher_a = create(:researcher, admin: admin_a)
      researcher_b = create(:researcher, admin: admin_b)

      ach_a = create(:achievement,
                     achievement_type: type_a,
                     achievement_status: status,
                     achievement_result: result,
                     achievement_participation: participation)
      create(:researcher_achievement, researcher: researcher_a, achievement: ach_a)

      ach_b = create(:achievement,
                     achievement_type: type_b,
                     achievement_status: create(:achievement_status, admin: admin_b),
                     achievement_result: create(:achievement_result, admin: admin_b),
                     achievement_participation: create(:achievement_participation, admin: admin_b))
      create(:researcher_achievement, researcher: researcher_b, achievement: ach_b)

      get '/api/v1/achievements/list', headers: json_auth_headers(admin_a)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('items').map { |i| i['id'] }
      expect(ids).to include(ach_a.id)
      expect(ids).not_to include(ach_b.id)
    end
  end

end
