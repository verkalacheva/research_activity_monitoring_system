# frozen_string_literal: true

# Тонкий слой над BaseInteractor: типичные операции с ActiveRecord и контрактами.
class BaseCommand < BaseInteractor
  protected

  def create_record(model_class, attributes)
    attrs = attributes.to_h.symbolize_keys
    if model_class.column_names.include?('admin_id') && Current.admin_id.present?
      attrs[:admin_id] ||= Current.admin_id
    end

    record = model_class.new(attrs)
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
    scope = tenant_scope_for(model_class)
    record = scope.find_by(id: id)
    if record
      success(record)
    else
      failure(:not_found, "#{model_class} with id #{id} not found")
    end
  end

  def tenant_scope_for(model_class)
    if model_class == Achievement
      Achievement.kept.joins(:achievement_type).where(achievement_types: { admin_id: Current.admin_id })
    elsif model_class.respond_to?(:for_current_admin)
      base = model_class
      base = base.kept if base.respond_to?(:kept)
      base.for_current_admin
    else
      model_class.all
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
