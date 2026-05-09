# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::SyncJobCancellation do
  def with_sync_store_redis(store = {})
    redis = Object.new
    redis.define_singleton_method(:setex) { |k, _, v| store[k] = v }
    redis.define_singleton_method(:get) { |k| store[k] }
    redis.define_singleton_method(:del) { |k| store.delete(k) }

    prev = Integrations::SyncJobStore.instance_variable_get(:@redis) if Integrations::SyncJobStore.instance_variable_defined?(:@redis)
    Integrations::SyncJobStore.instance_variable_set(:@redis, redis)
    yield store
  ensure
    if prev
      Integrations::SyncJobStore.instance_variable_set(:@redis, prev)
    elsif Integrations::SyncJobStore.instance_variable_defined?(:@redis)
      Integrations::SyncJobStore.remove_instance_variable(:@redis)
    end
  end

  describe '.request! / .requested? / .clear!' do
    it 'sets and reads cancel flag in Redis' do
      with_sync_store_redis({}) do |store|
        expect(described_class.requested?('j-1')).to be false

        described_class.request!('j-1')
        expect(store[described_class.key('j-1')]).to eq('1')
        expect(described_class.requested?('j-1')).to be true

        described_class.clear!('j-1')
        expect(store).to be_empty
        expect(described_class.requested?('j-1')).to be false
      end
    end

    it 'no-ops request! and clear! when job_id blank' do
      with_sync_store_redis({}) do |store|
        described_class.request!(nil)
        described_class.clear!('')
        expect(store).to be_empty
      end
    end
  end
end
