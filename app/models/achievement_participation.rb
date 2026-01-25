class AchievementParticipation < ApplicationRecord
  include SoftDeletable
  has_many :achievements

  before_save :round_points

  private

  def round_points
    self.points = points.round(1) if points.present?
  end
end

