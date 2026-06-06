# frozen_string_literal: true

# Выполнение кода в контексте tenant (admin): Sidekiq, фоновые потоки, interactor-цепочки.
module TenantContext
  module_function

  def with_user(user)
    previous = Current.user
    Current.user = user
    yield
  ensure
    Current.user = previous
  end

  def in_thread(user, &block)
    Thread.new do
      Current.user = user
      block.call
    ensure
      Current.reset
    end
  end
end
