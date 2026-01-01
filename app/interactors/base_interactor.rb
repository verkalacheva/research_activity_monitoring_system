module Interactors
  class BaseInteractor
    include Dry::Monads[:result, :do]
    extend Dry::Initializer

    def self.call(...)
      new(...).call
    end

    def call
      raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
    end
  end
end

