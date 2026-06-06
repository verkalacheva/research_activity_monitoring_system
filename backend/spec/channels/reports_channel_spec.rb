# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportsChannel, type: :channel do
  it 'subscribes to tenant-scoped stream' do
    admin = create(:user, role: 'admin')
    stub_connection current_user: admin
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("reports_channel:#{admin.id}")
  end
end
