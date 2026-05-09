# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/achievement_types', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/achievement_types/list
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_types/list' do
    get('list achievement types') do
      tags 'AchievementTypes'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before { create_list(:achievement_type, 3) }

      response(200, 'successful') do
        schema load_schema(:models, :achievement_types, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(3)
          expect(data['pagination']['total']).to eq(3)
          expect(data).to satisfy { |d| d.dig('pagination', 'limit') }
          expect(data).to satisfy { |d| d.dig('pagination', 'offset') }
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievement_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_type) { create(:achievement_type) }
    let(:id)               { achievement_type.id }

    get('show achievement type') do
      tags 'AchievementTypes'

      response(200, 'successful') do
        schema load_schema(:models, :AchievementType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(achievement_type.id)
          expect(data['title']).to eq(achievement_type.title)
          expect(data).to have_key('achievement_fields')
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
  # POST /api/v1/achievement_types
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_types' do
    post('create achievement type') do
      tags 'AchievementTypes'
      consumes 'application/json'

      parameter name: :achievement_type_attributes, in: :body, schema: load_schema(:requests, :achievement_types, :attributes)

      let(:achievement_type_attributes) do
        {
          achievement_type: {
            title:     'Новый тип',
            points:    2.5,
            icon_name: 'star',
            achievement_fields_attributes: [
              { title: 'Название работы', field_type: 'text', is_required: true }
            ]
          }
        }
      end

      response(201, 'successful — тип создан с полями') do
        schema load_schema(:models, :AchievementType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = AchievementType.find_by(title: 'Новый тип')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(data['achievement_fields'].size).to eq(1)
          expect(data['achievement_fields'].first['title']).to eq('Название работы')
        end
      end

      response(422, 'validation error — пустое название') do
        schema load_schema(:shared, :error)

        let(:achievement_type_attributes) { { achievement_type: { points: 1.0 } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('title')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/achievement_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_type) { create(:achievement_type, title: 'Старый тип', points: 1.0) }
    let(:id)               { achievement_type.id }

    patch('update achievement type') do
      tags 'AchievementTypes'
      consumes 'application/json'

      parameter name: :achievement_type_attributes, in: :body, schema: load_schema(:requests, :achievement_types, :attributes)

      let(:achievement_type_attributes) do
        { achievement_type: { title: 'Обновлённый тип', points: 3.0 } }
      end

      response(200, 'successful — тип обновлён') do
        schema load_schema(:models, :AchievementType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(achievement_type.id)
          expect(data['title']).to eq('Обновлённый тип')
          expect(achievement_type.reload.points).to eq(3.0)
        end
      end

      response(404, 'not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end

      response(422, 'validation error — пустое название') do
        schema load_schema(:shared, :error)

        let(:achievement_type_attributes) { { achievement_type: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(achievement_type.reload.title).to eq('Старый тип')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/achievement_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievement_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_type) { create(:achievement_type) }
    let(:id)               { achievement_type.id }

    delete('destroy achievement type') do
      tags 'AchievementTypes'

      response(204, 'successful — тип удалён') do
        run_test! do
          expect(AchievementType.kept.find_by(id: achievement_type.id)).to be_nil
          expect(AchievementType.find_by(id: achievement_type.id)).not_to be_nil
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
