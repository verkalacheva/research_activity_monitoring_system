# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/dev_employee_activity_types', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/dev_employee_activity_types/list
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_employee_activity_types/list' do
    get('list dev employee activity types') do
      tags 'DevEmployeeActivityTypes'

      before { create_list(:dev_employee_activity_type, 3) }

      response(200, 'successful') do
        schema load_schema(:models, :dev_employee_activity_types, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(3)
          expect(data['pagination']['total']).to eq(3)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dev_employee_activity_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_employee_activity_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:activity_type) { create(:dev_employee_activity_type) }
    let(:id)            { activity_type.id }

    get('show dev employee activity type') do
      tags 'DevEmployeeActivityTypes'

      response(200, 'successful') do
        schema load_schema(:models, :DevEmployeeActivityType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(activity_type.id)
          expect(data['title']).to eq(activity_type.title)
          expect(data['check_key']).to eq(activity_type.check_key)
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
  # POST /api/v1/dev_employee_activity_types
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_employee_activity_types' do
    post('create dev employee activity type') do
      tags 'DevEmployeeActivityTypes'
      consumes 'application/json'

      parameter name: :dev_employee_activity_type_attributes, in: :body, schema: load_schema(:requests, :dev_employee_activity_types, :attributes)

      let(:dev_employee_activity_type_attributes) do
        {
          dev_employee_activity_type: {
            title:     'PR-ревью',
            check_key: 'has_pr_reviews',
            points:    2.0
          }
        }
      end

      response(201, 'successful — тип создан') do
        schema load_schema(:models, :DevEmployeeActivityType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = DevEmployeeActivityType.find_by(title: 'PR-ревью')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(created.check_key).to eq('has_pr_reviews')
        end
      end

      response(422, 'validation error — отсутствует title') do
        schema load_schema(:shared, :error)

        let(:dev_employee_activity_type_attributes) do
          { dev_employee_activity_type: { check_key: 'some_key' } }
        end

        run_test! do |response|
          expect(response.status).to eq(422)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/dev_employee_activity_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_employee_activity_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:activity_type) { create(:dev_employee_activity_type, title: 'Старый вид', points: 1.0) }
    let(:id)            { activity_type.id }

    patch('update dev employee activity type') do
      tags 'DevEmployeeActivityTypes'
      consumes 'application/json'

      parameter name: :dev_employee_activity_type_attributes, in: :body, schema: load_schema(:requests, :dev_employee_activity_types, :attributes)

      let(:dev_employee_activity_type_attributes) do
        { dev_employee_activity_type: { title: 'Обновлённый вид', points: 3.0 } }
      end

      response(200, 'successful — тип обновлён') do
        schema load_schema(:models, :DevEmployeeActivityType)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['title']).to eq('Обновлённый вид')
          expect(activity_type.reload.points).to eq(3.0)
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
  # DELETE /api/v1/dev_employee_activity_types/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_employee_activity_types/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:activity_type) { create(:dev_employee_activity_type) }
    let(:id)            { activity_type.id }

    delete('destroy dev employee activity type') do
      tags 'DevEmployeeActivityTypes'

      response(204, 'successful — тип удалён') do
        run_test! do
          expect(DevEmployeeActivityType.find_by(id: activity_type.id)).to be_nil
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
