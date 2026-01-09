class AchievementType < ApplicationRecord
  has_many :achievement_fields, dependent: :destroy
  has_many :achievements, dependent: :destroy
  
  accepts_nested_attributes_for :achievement_fields, allow_destroy: true
end

