class BaseCommand
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
  rescue => e
    failure(error_type, e.message.to_s.force_encoding('UTF-8'))
  end

  def create_record(model_class, attributes)
    record = model_class.new(attributes)
    if record.save
      success(record)
    else
      failure(:database_error, record.errors.full_messages)
    end
  end

  def transaction
    ActiveRecord::Base.transaction do
      yield
    end
  rescue Dry::Monads::Do::Halt => e
    raise e # Allow Dry::Monads to handle the halt
  rescue => e
    failure(:transaction_error, e.message.to_s.force_encoding('UTF-8'))
  end

  def update_record(record, attributes)
    if record.update(attributes)
      success(record)
    else
      failure(:database_error, record.errors.full_messages)
    end
  end

  def destroy_record(record)
    if record.destroy
      success(record)
    else
      failure(:database_error, record.errors.full_messages)
    end
  end

  def find_record(model_class, id)
    record = model_class.find_by(id: id)
    if record
      success(record)
    else
      failure(:not_found, "#{model_class} with id #{id} not found")
    end
  end

  def validate(contract, params)
    result = contract.new.call(params)
    if result.success?
      success(result.to_h)
    else
      failure(:validation_error, result.errors.to_h)
    end
  end
end
