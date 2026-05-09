# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/achievement_participations', type: :request do
  path '/api/v1/achievement_participations/list' do
    get('list achievement participations') do
      tags 'AchievementParticipations'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before { create_list(:achievement_participation, 2) }

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_list)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(2)
          expect(data['pagination']['total']).to eq(2)
        end
      end
    end
  end

  path '/api/v1/achievement_participations/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:participation) { create(:achievement_participation) }
    let(:id)            { participation.id }

    get('show achievement participation') do
      tags 'AchievementParticipations'

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test! do |response|
          expect(response.parsed_body['id']).to eq(participation.id)
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

  path '/api/v1/achievement_participations' do
    post('create achievement participation') do
      tags 'AchievementParticipations'
      consumes 'application/json'

      parameter name: :achievement_participation_attributes, in: :body,
                schema: load_schema(:requests, :achievement_participations, :attributes)

      let(:achievement_participation_attributes) do
        { achievement_participation: { title: 'Руководитель', points: 1.0 } }
      end

      response(201, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = AchievementParticipation.find_by(title: 'Руководитель')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
        end
      end

      response(422, 'validation error') do
        schema load_schema(:shared, :error)

        let(:achievement_participation_attributes) { { achievement_participation: { title: '' } } }

        run_test! do |response|
          expect(response.parsed_body['errors']).to have_key('title')
        end
      end
    end
  end

  path '/api/v1/achievement_participations/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:participation) { create(:achievement_participation, title: 'Старый вид', points: 1.0) }
    let(:id)            { participation.id }

    patch('update achievement participation') do
      tags 'AchievementParticipations'
      consumes 'application/json'

      parameter name: :achievement_participation_attributes, in: :body,
                schema: load_schema(:requests, :achievement_participations, :attributes)

      let(:achievement_participation_attributes) do
        { achievement_participation: { title: 'Новый вид', points: 0.5 } }
      end

      response(200, 'successful') do
        schema load_schema(:shared, :taxonomy_item)

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['title']).to eq('Новый вид')
          expect(participation.reload.points).to eq(0.5)
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

        let(:achievement_participation_attributes) { { achievement_participation: { title: '' } } }

        run_test!(nil, :aggregate_failures) do |response|
          expect(response.parsed_body['type']).to eq('validation_error')
          expect(participation.reload.title).to eq('Старый вид')
        end
      end
    end

    delete('destroy achievement participation') do
      tags 'AchievementParticipations'

      response(204, 'successful') do
        run_test! do
          expect(AchievementParticipation.kept.find_by(id: participation.id)).to be_nil
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
