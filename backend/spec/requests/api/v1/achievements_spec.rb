# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/achievements', type: :request do
  # Общие таксономии, создаваемые один раз для всего describe-блока
  let(:achievement_type)          { create(:achievement_type) }
  let(:achievement_status)        { create(:achievement_status) }
  let(:achievement_result)        { create(:achievement_result) }
  let(:achievement_participation) { create(:achievement_participation) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievements/list
  # ---------------------------------------------------------------------------
  path '/api/v1/achievements/list' do
    get('list achievements') do
      tags 'Achievements'

      parameter name: :limit,  in: :query, type: :integer, required: false
      parameter name: :offset, in: :query, type: :integer, required: false

      before do
        achievement_type
        achievement_status
        achievement_result
        achievement_participation
        create_list(:achievement, 3,
                    achievement_type: achievement_type,
                    achievement_status: achievement_status,
                    achievement_result: achievement_result,
                    achievement_participation: achievement_participation)
      end

      response(200, 'successful') do
        schema load_schema(:models, :achievements, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(3)
          expect(data['pagination']['total']).to eq(3)
          expect(data).to satisfy { |d| d.dig('pagination', 'limit') }
          expect(data).to satisfy { |d| d.dig('pagination', 'offset') }
        end
      end

      response(200, 'pagination — limit=1') do
        schema load_schema(:models, :achievements, :List)

        let(:limit)  { 1 }
        let(:offset) { 0 }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(1)
          expect(data['pagination']['total']).to eq(3)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievements/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievements/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement) do
      create(:achievement,
             achievement_type: achievement_type,
             achievement_status: achievement_status,
             achievement_result: achievement_result,
             achievement_participation: achievement_participation)
    end
    let(:id) { achievement.id }

    get('show achievement') do
      tags 'Achievements'

      response(200, 'successful') do
        schema load_schema(:models, :Achievement)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(achievement.id)
          expect(data['achievement_type_id']).to eq(achievement_type.id)
          expect(data).to have_key('achievement_field_answers')
        end
      end

      response(404, 'achievement not found') do
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
  # POST /api/v1/achievements
  # ---------------------------------------------------------------------------
  path '/api/v1/achievements' do
    post('create achievement') do
      tags 'Achievements'
      consumes 'application/json'

      parameter name: :achievement_attributes, in: :body, schema: load_schema(:requests, :achievements, :attributes)

      let(:researcher) { create(:researcher) }

      let(:achievement_attributes) do
        {
          achievement: {
            achievement_type_id:          achievement_type.id,
            achievement_status_id:        achievement_status.id,
            achievement_result_id:        achievement_result.id,
            achievement_participation_id: achievement_participation.id,
            submission_date:              '2024-03-15',
            researcher_ids:               [researcher.id]
          }
        }
      end

      response(201, 'successful — достижение создано') do
        schema load_schema(:models, :Achievement)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = Achievement.find_by(id: data['id'])
          expect(created).not_to be_nil
          expect(created.achievement_type_id).to eq(achievement_type.id)
          expect(created.researchers).to include(researcher)
          expect(data['achievement_type_id']).to eq(achievement_type.id)
        end
      end

      response(422, 'validation error — обязательные ID отсутствуют') do
        schema load_schema(:shared, :error)

        let(:achievement_attributes) { { achievement: { submission_date: '2024-01-01' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('achievement_type_id')
          expect(data['errors']).to have_key('achievement_status_id')
          expect(data['errors']).to have_key('achievement_result_id')
          expect(data['errors']).to have_key('achievement_participation_id')
        end
      end

      response(404, 'validation error — несуществующий researcher_id') do

        let(:achievement_attributes) do
          {
            achievement: {
              achievement_type_id:          achievement_type.id,
              achievement_status_id:        achievement_status.id,
              achievement_result_id:        achievement_result.id,
              achievement_participation_id: achievement_participation.id,
              researcher_ids:               [999_999_999]
            }
          }
        end

        run_test! do |response|
          expect(response.status).to be_in([404, 422])
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/achievements/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievements/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement) do
      create(:achievement,
             achievement_type: achievement_type,
             achievement_status: achievement_status,
             achievement_result: achievement_result,
             achievement_participation: achievement_participation,
             submission_date: '2023-01-01')
    end
    let(:id) { achievement.id }

    let(:new_status) { create(:achievement_status, title: 'Международный', points: 2.0) }

    patch('update achievement') do
      tags 'Achievements'
      consumes 'application/json'

      parameter name: :achievement_attributes, in: :body, schema: load_schema(:requests, :achievements, :attributes)

      let(:achievement_attributes) do
        {
          achievement: {
            achievement_type_id:          achievement_type.id,
            achievement_status_id:        new_status.id,
            achievement_result_id:        achievement_result.id,
            achievement_participation_id: achievement_participation.id,
            submission_date:              '2024-06-01'
          }
        }
      end

      response(200, 'successful — достижение обновлено') do
        schema load_schema(:models, :Achievement)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(achievement.id)
          expect(achievement.reload.achievement_status_id).to eq(new_status.id)
          expect(achievement.reload.submission_date.to_date.to_s).to eq('2024-06-01')
        end
      end

      response(404, 'achievement not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end

      response(422, 'validation error — пустые обязательные поля') do
        schema load_schema(:shared, :error)

        let(:achievement_attributes) do
          { achievement: { achievement_type_id: nil, achievement_status_id: nil,
                           achievement_result_id: nil, achievement_participation_id: nil } }
        end

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(achievement.reload.achievement_type_id).to eq(achievement_type.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/achievements/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/achievements/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:achievement) do
      create(:achievement,
             achievement_type: achievement_type,
             achievement_status: achievement_status,
             achievement_result: achievement_result,
             achievement_participation: achievement_participation)
    end
    let(:id) { achievement.id }

    delete('destroy achievement') do
      tags 'Achievements'

      response(204, 'successful — достижение удалено') do
        run_test! do
          expect(Achievement.kept.find_by(id: achievement.id)).to be_nil
          expect(Achievement.find_by(id: achievement.id)).not_to be_nil
        end
      end

      response(404, 'achievement not found') do
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
