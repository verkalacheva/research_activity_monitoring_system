# frozen_string_literal: true

# Тонкий слой над BaseInteractor: типичные операции с ActiveRecord и контрактами.
class BaseCommand < BaseInteractor
  protected

  def create_record(model_class, attributes)
    record = model_class.new(attributes)
    if record.save
      success(record)
    else
      failure(:validation_error, record.errors.messages)
    end
  rescue ActiveRecord::RecordNotFound => e
    failure(:not_found, e.message)
  rescue ActiveRecord::RecordNotUnique
    failure(:validation_error, { base: ['has already been taken'] })
  end

  def update_record(record, attributes)
    if record.update(attributes)
      success(record)
    else
      failure(:validation_error, record.errors.messages)
    end
  rescue ActiveRecord::RecordNotFound => e
    failure(:not_found, e.message)
  rescue ActiveRecord::RecordNotUnique
    failure(:validation_error, { base: ['has already been taken'] })
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
