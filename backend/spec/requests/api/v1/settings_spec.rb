# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/settings', type: :request do
  # ---------------------------------------------------------------------------
  # GET /api/v1/settings
  # ---------------------------------------------------------------------------
  path '/api/v1/settings' do
    get('show settings') do
      tags 'Settings'

      context 'когда настройки не заданы' do
        response(200, 'successful — пустой набор настроек') do
          schema load_schema(:models, :settings, :show)

          run_test!(nil, :aggregate_failures) do |response|
            data = response.parsed_body

            expect(data).to have_key('settings')
            expect(data['settings']).to be_a(Hash)
          end
        end
      end

      context 'когда часть настроек задана' do
        before do
          create(:app_setting, key: 'llm_model_name', value: 'gpt-4o')
          create(:app_setting, key: 'llm_provider',   value: 'openai')
        end

        response(200, 'successful — содержит заданные ключи') do
          schema load_schema(:models, :settings, :show)

          run_test!(nil, :aggregate_failures) do |response|
            data = response.parsed_body

            expect(data['settings']['llm_model_name']).to eq('gpt-4o')
            expect(data['settings']['llm_provider']).to eq('openai')
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/settings
  # ---------------------------------------------------------------------------
  path '/api/v1/settings' do
    patch('update settings') do
      tags 'Settings'
      consumes 'application/json'

      parameter name: :settings_attributes, in: :body, schema: load_schema(:requests, :settings, :attributes)

      let(:settings_attributes) do
        {
          settings: {
            llm_model_name:    'claude-3-sonnet',
            llm_provider:      'anthropic',
            llm_api_base:      'https://api.anthropic.com',
            github_token:      'ghp_test_token'
          }
        }
      end

      response(200, 'successful — настройки обновлены') do
        schema load_schema(:models, :settings, :show)

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['settings']['llm_model_name']).to eq('claude-3-sonnet')
          expect(data['settings']['llm_provider']).to eq('anthropic')
          expect(data['settings']['github_token']).to eq('ghp_test_token')

          expect(AppSetting.find_by(key: 'llm_model_name')&.value).to eq('claude-3-sonnet')
          expect(AppSetting.find_by(key: 'github_token')&.value).to eq('ghp_test_token')
        end
      end

      response(200, 'successful — неизвестные ключи игнорируются') do
        schema load_schema(:models, :settings, :show)

        let(:settings_attributes) do
          { settings: { unknown_key: 'value', llm_provider: 'openai' } }
        end

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['settings']).not_to have_key('unknown_key')
          expect(data['settings']['llm_provider']).to eq('openai')
        end
      end

      response(200, 'successful — передача nil очищает значение') do
        schema load_schema(:models, :settings, :show)

        before { create(:app_setting, key: 'github_token', value: 'old_token') }

        let(:settings_attributes) { { settings: { github_token: nil } } }

        run_test!(nil, :aggregate_failures) do |response|
          data = response.parsed_body

          expect(data['settings']['github_token']).to be_nil
          expect(AppSetting.find_by(key: 'github_token')&.value).to be_nil
        end
      end
    end
  end
end
