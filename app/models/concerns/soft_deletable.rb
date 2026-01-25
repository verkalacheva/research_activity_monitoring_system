module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  def destroy
    update(deleted_at: Time.current)
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




