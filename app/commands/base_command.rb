class BaseCommand
  include ServiceObject

  protected

  def create_record(model_class, attributes)
    record = model_class.new(attributes)
    if record.save
      Success(record)
    else
      Failure(type: :database_error, errors: record.errors.full_messages)
    end
  end

  def transaction
    ActiveRecord::Base.transaction do
      yield
    end
  rescue Dry::Monads::Do::Halt => e
    raise e # Allow Dry::Monads to handle the halt
  rescue => e
    Failure(type: :transaction_error, message: e.message)
  end

  def update_record(record, attributes)
    if record.update(attributes)
      Success(record)
    else
      Failure(type: :database_error, errors: record.errors.full_messages)
    end
  end

  def destroy_record(record)
    if record.destroy
      Success(record)
    else
      Failure(type: :database_error, errors: record.errors.full_messages)
    end
  end

  def find_record(model_class, id)
    record = model_class.find_by(id: id)
    if record
      Success(record)
    else
      Failure(type: :not_found, message: "#{model_class} with id #{id} not found")
    end
  end

  def validate(contract, params)
    result = contract.new.call(params)
    if result.success?
      Success(result.to_h)
    else
      Failure(type: :validation_error, errors: result.errors.to_h)
    end
  end
end
