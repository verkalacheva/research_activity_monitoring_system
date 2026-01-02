module ServiceObject
  def self.included(base)
    base.include Dry::Monads[:result, :do]
    base.extend DependencyInitializer
    base.extend ClassMethods
  end

  module ClassMethods
    def call(...)
      new(...).call
    end
  end

  def call
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end
end

