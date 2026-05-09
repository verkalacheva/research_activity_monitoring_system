# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/achievement_statuses', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/achievement_statuses/list
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_statuses/list' do
    get('list achievement statuses') do
      tags 'AchievementStatuses'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before { create_list(:achievement_status, 4) }

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(4)
          expect(data['pagination']['total']).to eq(4)
          expect(data['items'].first).to have_key('title')
          expect(data['items'].first).to have_key('points')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievement_statuses/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_statuses/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_status) { create(:achievement_status) }
    let(:id)                 { achievement_status.id }

    get('show achievement status') do
      tags 'AchievementStatuses'

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(achievement_status.id)
          expect(data['title']).to eq(achievement_status.title)
        end
      end

      response(404, 'not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/achievement_statuses
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_statuses' do
    post('create achievement status') do
      tags 'AchievementStatuses'
      consumes 'application/json'

      parameter name: :achievement_status_attributes, in: :body, schema: load_schema(:requests, :achievement_statuses, :attributes)

      let(:achievement_status_attributes) do
        { achievement_status: { title: 'Международный ВАК', points: 2.0 } }
      end

      response(201, 'successful — статус создан') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = AchievementStatus.find_by(title: 'Международный ВАК')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(created.points).to eq(2.0)
        end
      end

      response(422, 'validation error — пустое название') do
        schema load_schema(:shared, :error)

        let(:achievement_status_attributes) { { achievement_status: { points: 1.0 } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('title')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/achievement_statuses/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_statuses/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_status) { create(:achievement_status, title: 'Старый статус', points: 1.0) }
    let(:id)                 { achievement_status.id }

    patch('update achievement status') do
      tags 'AchievementStatuses'
      consumes 'application/json'

      parameter name: :achievement_status_attributes, in: :body, schema: load_schema(:requests, :achievement_statuses, :attributes)

      let(:achievement_status_attributes) do
        { achievement_status: { title: 'Новый статус', points: 3.0 } }
      end

      response(200, 'successful — статус обновлён') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['title']).to eq('Новый статус')
          expect(achievement_status.reload.points).to eq(3.0)
        end
      end

      response(404, 'not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end

      response(422, 'validation error') do
        schema load_schema(:shared, :error)

        let(:achievement_status_attributes) { { achievement_status: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['type']).to eq('validation_error')
          expect(achievement_status.reload.title).to eq('Старый статус')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/achievement_statuses/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_statuses/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_status) { create(:achievement_status) }
    let(:id)                 { achievement_status.id }

    delete('destroy achievement status') do
      tags 'AchievementStatuses'

      response(204, 'successful — статус удалён') do
        run_test! do
          expect(AchievementStatus.kept.find_by(id: achievement_status.id)).to be_nil
          expect(AchievementStatus.find_by(id: achievement_status.id)).not_to be_nil
        end
      end

      response(404, 'not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end
    end
  end
end
