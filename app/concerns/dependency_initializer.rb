module DependencyInitializer
  def self.extended(base)
    base.extend Dry::Initializer

    base.define_singleton_method(:dependency) do |*args, **kwargs|
      option(*args, **kwargs)
    end

    base.define_singleton_method(:param) do |*args, **kwargs|
      param(*args, **kwargs)
    end
  end
end

