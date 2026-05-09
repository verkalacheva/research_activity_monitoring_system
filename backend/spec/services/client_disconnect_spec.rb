# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClientDisconnect do
  describe '.io_closed?' do
    it 'returns false when env has no socket' do
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for('/'))
      expect(described_class.io_closed?(request)).to be false
    end

    it 'returns true when puma.socket reports closed' do
      io = instance_double(IO, closed?: true)
      env = Rack::MockRequest.env_for('/').merge('puma.socket' => io)
      request = ActionDispatch::Request.new(env)
      expect(described_class.io_closed?(request)).to be true
    end

    it 'returns false when closed? raises' do
      io = Object.new
      def io.closed?
        raise IOError, 'closed stream'
      end
      env = Rack::MockRequest.env_for('/').merge('puma.socket' => io)
      request = ActionDispatch::Request.new(env)
      expect(described_class.io_closed?(request)).to be false
    end
  end
end
