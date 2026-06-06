# frozen_string_literal: true

module RequestAuthTenant
  mattr_accessor :admin
end

module AuthRequestHelpers
  extend RSpec::SharedContext

  before do |example|
    next if example.metadata[:skip_auth_headers]

    @auth_admin = create(:user)
    RequestAuthTenant.admin = @auth_admin
  end

  let(:auth_admin) { @auth_admin }
  let(:Authorization) do
    return nil if RSpec.current_example.metadata[:skip_auth_headers]

    "Bearer #{Auth::JwtService.encode(auth_admin)}"
  end
end

RSpec.configure do |config|
  config.include AuthRequestHelpers, type: :request

  config.after(:each, type: :request) do
    RequestAuthTenant.admin = nil
    @auth_admin = nil
  end

  config.define_derived_metadata(file_path: %r{spec/requests/api/v1/auth_spec\.rb$}) do |metadata|
    metadata[:skip_auth_headers] = true
  end

  # Command and interactor specs run commands directly (no HTTP stack),
  # so Current.user is never set via Authenticatable. Set it here so
  # for_current_admin scoping works and factories pick up the right admin.
  config.define_derived_metadata(file_path: %r{spec/(commands|interactors)/}) do |metadata|
    metadata[:needs_tenant_context] = true
  end

  config.before(:each, :needs_tenant_context) do
    @spec_admin = create(:user)
    RequestAuthTenant.admin = @spec_admin
    Current.user = @spec_admin
  end

  config.after(:each, :needs_tenant_context) do
    Current.reset
    RequestAuthTenant.admin = nil
    @spec_admin = nil
  end
end

def json_auth_headers(user = nil)
  user ||= create(:user)
  { 'Authorization' => "Bearer #{Auth::JwtService.encode(user)}" }
end
