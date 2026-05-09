# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportsChannel, type: :channel do
  it 'subscribes successfully' do
    stub_connection
    subscribe

    expect(subscription).to be_confirmed
  end
end
