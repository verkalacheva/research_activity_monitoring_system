class AchievementType < ApplicationRecord
  include SoftDeletable
  include TenantScoped
  # В API и формах не показываем поля с soft delete.
  has_many :achievement_fields, -> { kept }, dependent: :destroy, inverse_of: :achievement_type
  has_many :achievements, dependent: :destroy
  
  accepts_nested_attributes_for :achievement_fields, allow_destroy: true

  before_save :round_points

  private

  def round_points
    self.points = points.round(1) if points.present?
  end
end

