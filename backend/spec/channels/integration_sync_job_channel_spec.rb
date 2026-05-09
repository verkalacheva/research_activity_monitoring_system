# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntegrationSyncJobChannel, type: :channel do
  it 'rejects subscription without job_id' do
    stub_connection
    subscribe

    expect(subscription).to be_rejected
  end

  it 'confirms subscription when job_id is present' do
    stub_connection
    allow(Integrations::SyncJobStore).to receive(:read).with('job-uuid-1').and_return(
      { 'status' => 'queued', 'error' => nil }
    )

    subscribe(job_id: 'job-uuid-1')

    expect(subscription).to be_confirmed
  end
end
