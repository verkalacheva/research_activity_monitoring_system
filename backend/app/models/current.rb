# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def admin_id
    user&.admin_owner_id
  end
end
