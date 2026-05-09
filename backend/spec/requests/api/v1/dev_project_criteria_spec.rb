# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/dev_project_criteria', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/dev_project_criteria/list
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_project_criteria/list' do
    get('list dev project criteria') do
      tags 'DevProjectCriteria'

      before { create_list(:dev_project_criterion, 4) }

      response(200, 'successful') do
        schema load_schema(:models, :dev_project_criteria, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(4)
          expect(data['pagination']['total']).to eq(4)
          expect(data['items'].first).to have_key('check_key')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dev_project_criteria/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_project_criteria/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:criterion) { create(:dev_project_criterion) }
    let(:id)        { criterion.id }

    get('show dev project criterion') do
      tags 'DevProjectCriteria'

      response(200, 'successful') do
        schema load_schema(:models, :DevProjectCriterion)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(criterion.id)
          expect(data['title']).to eq(criterion.title)
          expect(data['check_key']).to eq(criterion.check_key)
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
  # POST /api/v1/dev_project_criteria
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_project_criteria' do
    post('create dev project criterion') do
      tags 'DevProjectCriteria'
      consumes 'application/json'

      parameter name: :dev_project_criterion_attributes, in: :body, schema: load_schema(:requests, :dev_project_criteria, :attributes)

      let(:dev_project_criterion_attributes) do
        {
          dev_project_criterion: {
            title:     'Наличие CI/CD',
            check_key: 'has_ci_cd',
            points:    3.0
          }
        }
      end

      response(201, 'successful — критерий создан') do
        schema load_schema(:models, :DevProjectCriterion)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = DevProjectCriterion.find_by(check_key: 'has_ci_cd')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(data['title']).to eq('Наличие CI/CD')
        end
      end

      response(422, 'validation error — отсутствует title') do
        schema load_schema(:shared, :error)

        let(:dev_project_criterion_attributes) do
          { dev_project_criterion: { check_key: 'some_key', points: 1.0 } }
        end

        run_test! do |response|
          expect(response.status).to eq(422)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/dev_project_criteria/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_project_criteria/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:criterion) { create(:dev_project_criterion, title: 'Старый критерий', points: 1.0) }
    let(:id)        { criterion.id }

    patch('update dev project criterion') do
      tags 'DevProjectCriteria'
      consumes 'application/json'

      parameter name: :dev_project_criterion_attributes, in: :body, schema: load_schema(:requests, :dev_project_criteria, :attributes)

      let(:dev_project_criterion_attributes) do
        { dev_project_criterion: { title: 'Обновлённый критерий', points: 5.0 } }
      end

      response(200, 'successful — критерий обновлён') do
        schema load_schema(:models, :DevProjectCriterion)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['title']).to eq('Обновлённый критерий')
          expect(criterion.reload.points).to eq(5.0)
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
  # DELETE /api/v1/dev_project_criteria/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/dev_project_criteria/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:criterion) { create(:dev_project_criterion) }
    let(:id)        { criterion.id }

    delete('destroy dev project criterion') do
      tags 'DevProjectCriteria'

      response(204, 'successful — критерий удалён') do
        run_test! do
          expect(DevProjectCriterion.find_by(id: criterion.id)).to be_nil
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
