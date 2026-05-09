# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/researchers/dev_activities', type: :request do
  let(:researcher)    { create(:researcher) }
  let(:activity_type) { create(:dev_employee_activity_type) }
  let(:activity) do
    create(:researcher_dev_activity,
           researcher: researcher,
           dev_employee_activity_type: activity_type,
           count: 10,
           date: '2024-06-01')
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/researchers/:researcher_id/dev_activities/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/{researcher_id}/dev_activities/{id}' do
    parameter name: :researcher_id, in: :path, type: :integer
    parameter name: :id,            in: :path, type: :integer

    let(:researcher_id) { researcher.id }
    let(:id)            { activity.id }

    patch('update researcher dev activity') do
      tags 'ResearcherDevActivities'
      consumes 'application/json'

      parameter name: :dev_activity_attributes, in: :body, schema: load_schema(:requests, :researcher_dev_activities, :attributes)

      let(:dev_activity_attributes) do
        { dev_activity: { count: 25, date: '2024-09-15' } }
      end

      response(200, 'successful — активность обновлена') do
        schema load_schema(:models, :ResearcherDevActivity)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(activity.id)
          expect(data['count']).to eq(25)
          expect(activity.reload.count).to eq(25)
          expect(activity.reload.date.to_s).to eq('2024-09-15')
          expect(data).to have_key('dev_employee_activity_type')
        end
      end

      response(404, 'researcher not found') do
        schema load_schema(:shared, :error)

        let(:researcher_id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end

      response(404, 'activity not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end

      response(404, 'activity принадлежит другому исследователю') do
        schema load_schema(:shared, :error)

        let(:other_researcher) { create(:researcher) }
        let(:researcher_id)   { other_researcher.id }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/researchers/:researcher_id/dev_activities/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/{researcher_id}/dev_activities/{id}' do
    parameter name: :researcher_id, in: :path, type: :integer
    parameter name: :id,            in: :path, type: :integer

    let(:researcher_id) { researcher.id }
    let(:id)            { activity.id }

    delete('destroy researcher dev activity') do
      tags 'ResearcherDevActivities'

      response(204, 'successful — активность удалена') do
        run_test! do
          expect(ResearcherDevActivity.find_by(id: activity.id)).to be_nil
        end
      end

      response(404, 'researcher not found') do
        schema load_schema(:shared, :error)

        let(:researcher_id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end

      response(404, 'activity not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          expect(response.parsed_body['type']).to eq('not_found')
        end
      end
    end
  end
end
