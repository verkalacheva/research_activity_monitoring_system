# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/selectors', type: :request do
  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/researchers
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/researchers' do
    post('selector: researchers') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:researcher1) { create(:researcher, name: 'Иван',  surname: 'Иванов',  second_name: 'Александрович', subject_area: 'Физика') }
      let!(:researcher2) { create(:researcher, name: 'Пётр',  surname: 'Петров',  second_name: 'Сергеевич',     subject_area: 'Химия') }
      let!(:researcher3) { create(:researcher, name: 'Сидор', surname: 'Сидоров', second_name: 'Николаевич',    subject_area: 'Физика') }

      let(:filter_params) { {} }

      response(200, 'successful — список всех') do
        schema load_schema(:models, :selectors, :items_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to be >= 3
          expect(data).to have_key('pagination')
        end
      end

      response(200, 'successful — фильтрация по query') do
        schema load_schema(:models, :selectors, :items_list)

        let(:filter_params) { { query: 'иванов' } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          ids = data['items'].map { |r| r['id'] }
          expect(ids).to include(researcher1.id)
          expect(ids).not_to include(researcher2.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/teams
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/teams' do
    post('selector: teams') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:team1) { create(:team, title: 'Alpha') }
      let!(:team2) { create(:team, title: 'Beta') }
      let(:filter_params) { {} }

      response(200, 'successful — все команды') do
        schema load_schema(:models, :selectors, :items_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to be >= 2
        end
      end

      response(200, 'successful — поиск по названию') do
        schema load_schema(:models, :selectors, :items_list)

        let(:filter_params) { { query: 'alpha' } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          ids = data['items'].map { |t| t['id'] }
          expect(ids).to include(team1.id)
          expect(ids).not_to include(team2.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/achievement_types
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/achievement_types' do
    post('selector: achievement_types') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:type1) { create(:achievement_type, title: 'Статья') }
      let!(:type2) { create(:achievement_type, title: 'Грант') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to be >= 2
          expect(data['items'].map { |t| t['id'] }).to include(type1.id, type2.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/achievement_statuses
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/achievement_statuses' do
    post('selector: achievement_statuses') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:status1) { create(:achievement_status, title: 'ВАК') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test! do |response|
          expect(response.parsed_body['items'].map { |s| s['id'] }).to include(status1.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/achievement_results
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/achievement_results' do
    post('selector: achievement_results') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:result1) { create(:achievement_result, title: 'Победитель') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test! do |response|
          expect(response.parsed_body['items'].map { |r| r['id'] }).to include(result1.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/achievement_participations
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/achievement_participations' do
    post('selector: achievement_participations') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:participation1) { create(:achievement_participation, title: 'Единственный автор') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test! do |response|
          expect(response.parsed_body['items'].map { |p| p['id'] }).to include(participation1.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/dev_employee_activity_types
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/dev_employee_activity_types' do
    post('selector: dev_employee_activity_types') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:act_type) { create(:dev_employee_activity_type, title: 'Commits') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test! do |response|
          expect(response.parsed_body['items'].map { |t| t['id'] }).to include(act_type.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/selectors/dev_project_criteria
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/dev_project_criteria' do
    post('selector: dev_project_criteria') do
      tags 'Selectors'
      consumes 'application/json'

      parameter name: :filter_params, in: :body, schema: load_schema(:requests, :selectors, :filter_params)

      let!(:criterion) { create(:dev_project_criterion, title: 'Tests') }
      let(:filter_params) { {} }

      response(200, 'successful') do
        schema load_schema(:models, :selectors, :items_list)

        run_test! do |response|
          expect(response.parsed_body['items'].map { |c| c['id'] }).to include(criterion.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/selectors/github_check_keys
  # ---------------------------------------------------------------------------
  path '/api/v1/selectors/github_check_keys' do
    get('github check keys') do
      tags 'Selectors'

      response(200, 'successful — возвращает ключи и метки') do
        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data).to have_key('criteria_keys')
          expect(data).to have_key('activity_keys')
          expect(data).to have_key('category_labels')
          expect(data['criteria_keys']).to be_an(Array).or be_a(Hash)
          expect(data['activity_keys']).to be_an(Array).or be_a(Hash)
        end
      end
    end
  end
end
