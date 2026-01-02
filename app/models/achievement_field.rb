class AchievementField < ApplicationRecord
  has_many :achievement_type_fields
  has_many :achievement_types, through: :achievement_type_fields
  has_many :achievement_field_answers
end

