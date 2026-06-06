# frozen_string_literal: true

module TenantScopedHelpers
  extend ActiveSupport::Concern

  private

  def tenant_scope(model_class)
    if model_class == Achievement
      Achievement.kept.joins(:achievement_type).where(achievement_types: { admin_id: Current.admin_id })
    elsif model_class.respond_to?(:for_current_admin)
      model_class.for_current_admin
    else
      model_class.all
    end
  end

  def find_tenant_record!(model_class, id)
    tenant_scope(model_class).find(id)
  end

  def build_tenant_record(model_class, attributes)
    record = model_class.new(attributes)
    if model_class.column_names.include?('admin_id') && Current.admin_id.present?
      record.admin_id = Current.admin_id
    end
    record
  end
end
