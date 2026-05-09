# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/achievement_results', type: :request do
  path '/api/v1/achievement_results/list' do
    get('list achievement results') do
      tags 'AchievementResults'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before { create_list(:achievement_result, 3) }

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(3)
          expect(data['pagination']['total']).to eq(3)
        end
      end
    end
  end

  path '/api/v1/achievement_results/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_result) { create(:achievement_result) }
    let(:id)                 { achievement_result.id }

    get('show achievement result') do
      tags 'AchievementResults'

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test! do |response|
          expect(response.parsed_body['id']).to eq(achievement_result.id)
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

  path '/api/v1/achievement_results' do
    post('create achievement result') do
      tags 'AchievementResults'
      consumes 'application/json'

      parameter name: :achievement_result_attributes, in: :body, schema: load_schema(:requests, :achievement_results, :attributes)

      let(:achievement_result_attributes) do
        { achievement_result: { title: 'Призовое место', points: 2.0 } }
      end

      response(201, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = AchievementResult.find_by(title: 'Призовое место')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
        end
      end

      response(422, 'validation error') do
        schema load_schema(:shared, :error)

        let(:achievement_result_attributes) { { achievement_result: { points: 1.0 } } }

        run_test! do |response|
          expect(response.parsed_body['errors']).to have_key('title')
        end
      end
    end
  end

  path '/api/v1/achievement_results/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement_result) { create(:achievement_result, title: 'Старый результат') }
    let(:id)                 { achievement_result.id }

    patch('update achievement result') do
      tags 'AchievementResults'
      consumes 'application/json'

      parameter name: :achievement_result_attributes, in: :body, schema: load_schema(:requests, :achievement_results, :attributes)

      let(:achievement_result_attributes) do
        { achievement_result: { title: 'Новый результат', points: 1.5 } }
      end

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['title']).to eq('Новый результат')
          expect(achievement_result.reload.title).to eq('Новый результат')
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

        let(:achievement_result_attributes) { { achievement_result: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['type']).to eq('validation_error')
          expect(achievement_result.reload.title).to eq('Старый результат')
        end
      end
    end

    delete('destroy achievement result') do
      tags 'AchievementResults'

      response(204, 'successful') do
        run_test! do
          expect(AchievementResult.kept.find_by(id: achievement_result.id)).to be_nil
          expect(AchievementResult.find_by(id: achievement_result.id)).not_to be_nil
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
