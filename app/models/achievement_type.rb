class AchievementType < ApplicationRecord
  has_many :achievement_type_fields
  has_many :achievement_fields, through: :achievement_type_fields
  has_many :achievements
end

