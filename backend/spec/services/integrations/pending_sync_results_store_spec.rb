# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::PendingSyncResultsStore do
  def with_fake_redis(mem = {})
    redis = Object.new
    redis.define_singleton_method(:get) { |k| mem[k] }
    redis.define_singleton_method(:setex) { |k, _, v| mem[k] = v }
    redis.define_singleton_method(:del) { mem.clear }

    prev = described_class.instance_variable_get(:@redis) if described_class.instance_variable_defined?(:@redis)
    described_class.instance_variable_set(:@redis, redis)
    yield mem
  ensure
    if prev
      described_class.instance_variable_set(:@redis, prev)
    elsif described_class.instance_variable_defined?(:@redis)
      described_class.remove_instance_variable(:@redis)
    end
  end

  describe '.replace_daily_sync_entry' do
    it 'writes JSON to tenant redis key' do
      admin = create(:user)
      with_fake_redis({}) do |mem|
        described_class.replace_daily_sync_entry(
          { 'provider' => 'daily_sync', 'label' => 'Daily', 'results' => [{ 'a' => 1 }] },
          admin_id: admin.id
        )

        expect(mem[described_class.redis_key(admin.id)]).to include('daily_sync')
      end
    end
  end
end
