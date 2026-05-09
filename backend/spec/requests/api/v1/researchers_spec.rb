# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/researchers', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/researchers/list
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/list' do
    get('list researchers') do
      tags 'Researchers'

      parameter name: :limit,  in: :query, type: :integer, required: false, description: 'Размер страницы'
      parameter name: :offset, in: :query, type: :integer, required: false, description: 'Смещение'

      let!(:researcher1) { create(:researcher) }
      let!(:researcher2) { create(:researcher) }

      response(200, 'successful') do
        schema load_schema(:models, :researchers, :List)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to be >= 2
          expect(data).to have_key('pagination')
          expect(data).to satisfy { |d| d.dig('pagination', 'limit') }
          expect(data).to satisfy { |d| d.dig('pagination', 'offset') }
        end
      end

      response(200, 'pagination — только первая запись') do
        schema load_schema(:models, :researchers, :List)

        let(:limit)  { 1 }
        let(:offset) { 0 }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['items'].size).to eq(1)
          expect(data['pagination']['total']).to be >= 2
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/researchers/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'ID исследователя'

    let(:researcher) { create(:researcher) }
    let(:id)         { researcher.id }

    get('show researcher') do
      tags 'Researchers'

      response(200, 'successful') do
        schema load_schema(:models, :Researcher)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(researcher.id)
          expect(data['name']).to eq(researcher.name)
          expect(data['surname']).to eq(researcher.surname)
          expect(data).to have_key('is_leader')
          expect(data).to have_key('total_dev_points')
          expect(data).to have_key('achievements')
        end
      end

      response(404, 'researcher not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/researchers
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers' do
    post('create researcher') do
      tags 'Researchers'
      consumes 'application/json'

      parameter name: :researcher_attributes, in: :body, schema: load_schema(:requests, :researchers, :attributes)

      let(:researcher_attributes) do
        {
          researcher: {
            name:    'Пётр',
            surname: 'Петров',
            second_name:      'Петрович',
            degree_level:     'к.т.н.',
            subject_area:     'Математика',
            employment_status: 'employed'
          }
        }
      end

      response(201, 'successful — исследователь создан') do
        schema load_schema(:models, :Researcher)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          created = Researcher.find_by(name: 'Пётр', surname: 'Петров')
          expect(created).not_to be_nil
          expect(data['id']).to eq(created.id)
          expect(data['name']).to eq('Пётр')
          expect(data['surname']).to eq('Петров')
        end
      end

      response(422, 'validation error — обязательные поля отсутствуют') do
        schema load_schema(:shared, :error)

        let(:researcher_attributes) { { researcher: { degree_level: 'к.т.н.' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('name')
          expect(data['errors']).to have_key('surname')
        end
      end

      response(422, 'validation error — дублирование orcid_id') do
        schema load_schema(:shared, :error)

        before { create(:researcher, :with_orcid, orcid_id: '0000-0001-0002-0003') }

        let(:researcher_attributes) do
          { researcher: { name: 'Иван', surname: 'Иванов', orcid_id: '0000-0001-0002-0003' } }
        end

        run_test! do |response|
          data = response.parsed_body

          expect(response.status).to be_in([422, 500])
          expect(Researcher.where(orcid_id: '0000-0001-0002-0003').count).to eq(1)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/researchers/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'ID исследователя'

    let(:researcher) { create(:researcher, name: 'Старое', surname: 'Имя') }
    let(:id)         { researcher.id }

    patch('update researcher') do
      tags 'Researchers'
      consumes 'application/json'

      parameter name: :researcher_attributes, in: :body, schema: load_schema(:requests, :researchers, :attributes)

      let(:researcher_attributes) do
        { researcher: { name: 'Новое', surname: 'ОбновлённоеИмя' } }
      end

      response(200, 'successful — исследователь обновлён') do
        schema load_schema(:models, :Researcher)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['id']).to eq(researcher.id)
          expect(data['name']).to eq('Новое')
          expect(data['surname']).to eq('ОбновлённоеИмя')
          expect(researcher.reload.name).to eq('Новое')
        end
      end

      response(404, 'researcher not found') do
        schema load_schema(:shared, :error)

        let(:id) { 999_999_999 }

        run_test! do |response|
          data = response.parsed_body

          expect(data['type']).to eq('not_found')
        end
      end

      response(422, 'validation error — пустое имя') do
        schema load_schema(:shared, :error)

        let(:researcher_attributes) { { researcher: { name: '', surname: 'Иванов' } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['type']).to eq('validation_error')
          expect(data['errors']).to have_key('name')
          expect(researcher.reload.name).to eq('Старое')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/researchers/:id
  # ---------------------------------------------------------------------------
  path '/api/v1/researchers/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'ID исследователя'

    let(:researcher) { create(:researcher) }
    let(:id)         { researcher.id }

    delete('destroy researcher') do
      tags 'Researchers'

      response(204, 'successful — исследователь удалён (soft delete)') do
        run_test! do
          expect(Researcher.kept.find_by(id: researcher.id)).to be_nil
          expect(Researcher.find_by(id: researcher.id)).not_to be_nil
          expect(Researcher.find_by(id: researcher.id).deleted_at).not_to be_nil
        end
      end

      response(404, 'researcher not found') do
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
