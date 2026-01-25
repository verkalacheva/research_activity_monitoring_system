class AchievementType < ApplicationRecord
  include SoftDeletable
  has_many :achievement_fields, dependent: :destroy
  has_many :achievements, dependent: :destroy
  
  accepts_nested_attributes_for :achievement_fields, allow_destroy: true

  before_save :round_points

  private

  def round_points
    self.points = points.round(1) if points.present?
  end
end

