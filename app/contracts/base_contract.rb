require 'dry-validation'

class BaseContract < Dry::Validation::Contract
  config.messages.backend = :i18n
  config.messages.top_namespace = 'contracts'
end

