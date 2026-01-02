class Achievement < ApplicationRecord
  belongs_to :achievement_type
  belongs_to :achievement_status
  belongs_to :achievement_result
  belongs_to :achievement_participation
  belongs_to :achievement_field_answer, optional: true
  
  has_many :researcher_achievements
  has_many :researchers, through: :researcher_achievements
end

