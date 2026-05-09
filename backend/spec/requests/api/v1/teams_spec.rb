# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/teams', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/teams/list
  # ---------------------------------------------------------------------------
  path '/api/v1/teams/list' do
    get('list teams') do
      tags 'Teams'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before { create_list(:team, 3) }

      response(200, 'successful') do
        schema load_schema(:models, :teams, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(3)
          expect(data['pagination']['total']).to eq(3)
          expect(data).to satisfy { |d| d.dig('pagination', 'limit') }
          expect(data).to satisfy { |d| d.dig('pagination', 'offset') }
        end
      end

      response(200, 'pagination — limit=2') do
        schema load_schema(:models, :teams, :List)

        let(:limit)  { 2 }
        let(:offset) { 0 }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(2)
          expect(data['pagination']['total']).to eq(3)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/teams/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/teams/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:researcher) { create(:researcher) }
    let(:team)       { create(:team, :with_leader, researchers: [researcher]) }
    let(:id)         { team.id }

    get('show team') do
      tags 'Teams'

      response(200, 'successful') do
        schema load_schema(:models, :Team)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(team.id)
          expect(data['title']).to eq(team.title)
          expect(data).to have_key('researchers')
          expect(data).to have_key('leader')
          expect(data['researchers'].map { |r| r['id'] }).to include(researcher.id)
        end
      end

      response(404, 'team not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/teams
  # ---------------------------------------------------------------------------
  path '/api/v1/teams' do
    post('create team') do
      tags 'Teams'
      consumes 'application/json'

      parameter name: :team_attributes, in: :body, schema: load_schema(:requests, :teams, :attributes)

      let(:leader)      { create(:researcher) }
      let(:researcher1) { create(:researcher) }
      let(:researcher2) { create(:researcher) }

      let(:team_attributes) do
        {
          team: {
            title:          'Новая команда',
            github_repo_url: 'https://github.com/org/new-project',
            leader_id:       leader.id,
            researcher_ids:  [researcher1.id, researcher2.id]
          }
        }
      end

      response(201, 'successful — команда создана') do
        schema load_schema(:models, :Team)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = Team.find_by(title: 'Новая команда')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(data['title']).to eq('Новая команда')
          expect(created.researchers.map(&:id)).to include(researcher1.id, researcher2.id)
          expect(created.leader_id).to eq(leader.id)
        end
      end

      response(422, 'validation error — название отсутствует') do
        schema load_schema(:shared, :error)

        let(:team_attributes) { { team: { github_repo_url: 'https://github.com/org/repo' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('title')
        end
      end

      response(422, 'validation error — пустое название') do
        schema load_schema(:shared, :error)

        let(:team_attributes) { { team: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('title')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/teams/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/teams/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:team) { create(:team, title: 'Старое название') }
    let(:id)   { team.id }

    patch('update team') do
      tags 'Teams'
      consumes 'application/json'

      parameter name: :team_attributes, in: :body, schema: load_schema(:requests, :teams, :attributes)

      let(:new_leader) { create(:researcher) }

      let(:team_attributes) do
        {
          team: {
            title:    'Обновлённое название',
            leader_id: new_leader.id
          }
        }
      end

      response(200, 'successful — команда обновлена') do
        schema load_schema(:models, :Team)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(team.id)
          expect(data['title']).to eq('Обновлённое название')
          expect(team.reload.title).to eq('Обновлённое название')
          expect(team.reload.leader_id).to eq(new_leader.id)
        end
      end

      response(404, 'team not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end

      response(422, 'validation error — пустое название') do
        schema load_schema(:shared, :error)

        let(:team_attributes) { { team: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(team.reload.title).to eq('Старое название')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/teams/:id/update_criteria
  # ---------------------------------------------------------------------------
  path '/api/v1/teams/{id}/update_criteria' do
    parameter name: :id, in: :path, type: :integer

    let(:team) { create(:team) }
    let(:id)   { team.id }

    put('update team dev criteria') do
      tags 'Teams'
      consumes 'application/json'

      parameter name: :criteria_params, in: :body, schema: {
        type: :object,
        properties: {
          criterion_ids: {
            type: :array,
            items: { type: :integer }
          }
        }
      }

      let(:criterion1) { create(:dev_project_criterion) }
      let(:criterion2) { create(:dev_project_criterion) }

      let(:criteria_params) { { criterion_ids: [criterion1.id, criterion2.id] } }

      response(200, 'successful — критерии обновлены') do
        schema load_schema(:models, :Team)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(team.id)
          expect(team.dev_project_criteria.map(&:id)).to include(criterion1.id, criterion2.id)
        end
      end

      response(200, 'successful — очистка критериев') do
        schema load_schema(:models, :Team)

        let(:criteria_params) { { criterion_ids: [] } }

        run_test! do
          expect(team.team_dev_criteria.reload.count).to eq(0)
        end
      end

      response(404, 'team not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/teams/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/teams/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:team) { create(:team) }
    let(:id)   { team.id }

    delete('destroy team') do
      tags 'Teams'

      response(204, 'successful — команда удалена (soft delete)') do
        run_test! do
          expect(Team.kept.find_by(id: team.id)).to be_nil
          expect(Team.find_by(id: team.id)).not_to be_nil
        end
      end

      response(404, 'team not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end
    end
  end
end
