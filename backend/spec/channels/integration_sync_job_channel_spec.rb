# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntegrationSyncJobChannel, type: :channel do
  let(:admin) { create(:user, role: 'admin') }

  it 'rejects subscription without job_id' do
    stub_connection current_user: admin
    subscribe

    expect(subscription).to be_rejected
  end

  it 'rejects subscription when job is not found for tenant' do
    stub_connection current_user: admin
    allow(Integrations::SyncJobStore).to receive(:read)
      .with(admin_id: admin.id, job_id: 'job-uuid-1')
      .and_return(nil)

    subscribe(job_id: 'job-uuid-1')

    expect(subscription).to be_rejected
  end

  it 'confirms subscription and streams tenant-scoped channel when job exists' do
    stub_connection current_user: admin
    allow(Integrations::SyncJobStore).to receive(:read)
      .with(admin_id: admin.id, job_id: 'job-uuid-1')
      .and_return({ 'status' => 'queued', 'error' => nil, 'admin_id' => admin.id.to_s })

    subscribe(job_id: 'job-uuid-1')

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("integration_sync_job:#{admin.id}:job-uuid-1")
  end
end
