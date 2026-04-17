# frozen_string_literal: true

# Базовый объект для сценариев без привязки к HTTP/контроллеру: монады, execute, общие ошибки.
class BaseInteractor
  include ServiceObject

  protected

  def success(value)
    Success(value)
  end

  def failure(type, data)
    case data
    when Hash, Array
      Failure(type: type, errors: data)
    else
      Failure(type: type, message: data)
    end
  end

  def execute(error_type = :internal_error)
    result = yield
    result.is_a?(Dry::Monads::Result) ? result : success(result)
  rescue StandardError => e
    failure(error_type, e.message.to_s.force_encoding('UTF-8'))
  end

  def transaction
    ActiveRecord::Base.transaction do
      yield
    end
  rescue Dry::Monads::Do::Halt => e
    raise e
  rescue StandardError => e
    failure(:transaction_error, e.message.to_s.force_encoding('UTF-8'))
  end
end
