module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(arel_table[:deleted_at].eq(nil)) }
    scope :deleted, -> { where(arel_table[:deleted_at].not_eq(nil)) }
  end

  def destroy
    update_columns(deleted_at: Time.current)
    self
  end

  def kept?
    deleted_at.nil?
  end

  def deleted?
    !kept?
  end

  def restore
    update(deleted_at: nil)
  end
end






