class Achievement < ApplicationRecord
  belongs_to :achievement_type
  belongs_to :achievement_status
  belongs_to :achievement_result
  belongs_to :achievement_participation
  
  has_many :achievement_field_answers, dependent: :destroy
  has_many :researcher_achievements
  has_many :researchers, through: :researcher_achievements

  accepts_nested_attributes_for :achievement_field_answers
end

