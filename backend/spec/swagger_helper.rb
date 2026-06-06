# frozen_string_literal: true

require 'rails_helper'

# ---------------------------------------------------------------------------
# rswag_ref helper — ссылка на YAML-схему в spec/support/definitions/v1/
# Использование: rswag_ref(:models, :Researcher)
#                rswag_ref(:requests, :researchers, :attributes)
#                rswag_ref(:shared, :error)
# ---------------------------------------------------------------------------
DEFINITIONS_ROOT = File.join(__dir__, 'support', 'definitions', 'v1').freeze

def rswag_ref(*parts)
  rel_path = parts.map(&:to_s).join('/')
  abs_path = File.join(DEFINITIONS_ROOT, "#{rel_path}.yaml")
  raise "YAML-схема не найдена: #{abs_path}" unless File.exist?(abs_path)
  abs_path
end

# Хелпер загружает YAML-схему как Ruby-хеш — удобно для inline-проверок.
def load_schema(*parts)
  YAML.load_file(rswag_ref(*parts), symbolize_names: false)
end

RSpec.configure do |config|
  # rswag-specs configuration — required for swagger DSL (path/get/response/run_test!)
  config.openapi_root = Rails.root.to_s + '/swagger'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: { title: 'Research Activity Monitoring API V1', version: 'v1' },
      paths: {},
      servers: [{ url: 'http://localhost:3000' }]
    }
  }

  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  # Inject Authorization header parameter into rswag operation metadata so that
  # let(:Authorization) from AuthRequestHelpers is picked up by run_test!
  config.before(:each) do |example|
    next unless example.metadata[:operation]
    next if example.metadata[:skip_auth_headers]

    existing_params = Array(example.metadata.dig(:operation, :parameters))
    next if existing_params.any? { |p| p[:name].to_s == 'Authorization' }

    example.metadata[:operation] = example.metadata[:operation].merge(
      parameters: [{ name: :Authorization, in: :header, type: :string, required: false }] + existing_params
    )
  end
end

