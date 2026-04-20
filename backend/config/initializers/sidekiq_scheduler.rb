# frozen_string_literal: true

# Расписание из config/sidekiq.yml (ключ :schedule) обрабатывается только в процессе Sidekiq.
Sidekiq.configure_server do
  require 'sidekiq-scheduler'
end
