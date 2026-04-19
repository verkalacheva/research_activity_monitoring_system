class AchievementField < ApplicationRecord
  include SoftDeletable
  belongs_to :achievement_type, inverse_of: :achievement_fields
  has_many :achievement_field_answers, dependent: :destroy
end

