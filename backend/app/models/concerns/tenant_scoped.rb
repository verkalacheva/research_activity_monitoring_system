# frozen_string_literal: true

module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :admin, class_name: 'User'

    scope :for_admin_id, lambda { |admin_id|
      admin_id.present? ? where(admin_id: admin_id) : none
    }

    scope :for_current_admin, lambda {
      if Current.admin_id
        where(admin_id: Current.admin_id)
      else
        none
      end
    }
  end

  class_methods do
    def tenant_find_by(admin_id, attributes)
      for_admin_id(admin_id).find_by(attributes)
    end

    def tenant_find_or_create_by!(admin_id, attributes, &block)
      for_admin_id(admin_id).find_or_create_by!(attributes, &block)
    end
  end
end
