require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module ResearchActivityMonitoringSystem
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = true

    # 1. Убеждаемся, что lib не попадает в пути автозагрузки
    config.autoload_paths.delete(Rails.root.join("lib").to_s)
    config.eager_load_paths.delete(Rails.root.join("lib").to_s)

    # 2. Добавляем lib в $LOAD_PATH вручную
    $LOAD_PATH.unshift(Rails.root.join('lib').to_s)

    # 3. Явно приказываем Zeitwerk игнорировать папку со сгенерированными файлами
    config.after_initialize do
      Rails.autoloaders.main.ignore(Rails.root.join('lib/grpc_reports'))
    end
  end
end

