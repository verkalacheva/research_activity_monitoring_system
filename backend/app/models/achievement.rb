class Achievement < ApplicationRecord
  include SoftDeletable

  belongs_to :achievement_type
  belongs_to :achievement_status
  belongs_to :achievement_result
  belongs_to :achievement_participation
  
  has_many :achievement_field_answers, dependent: :destroy
  has_many :researcher_achievements, dependent: :destroy
  has_many :researchers, through: :researcher_achievements

  accepts_nested_attributes_for :achievement_field_answers

  before_save :calculate_points
  private

  def calculate_points
    type_p = achievement_type&.points || 0
    status_p = achievement_status&.points || 1
    result_p = achievement_result&.points || 1
    participation_p = achievement_participation&.points || 1
    
    self.points = (type_p * status_p * result_p * participation_p).round(1)
  end
end

